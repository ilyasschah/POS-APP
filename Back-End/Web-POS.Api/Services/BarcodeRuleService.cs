using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    /// <summary>Reads and replaces a company's barcode nomenclature.</summary>
    public class BarcodeRuleService
    {
        private readonly AppDbContext _db;

        public BarcodeRuleService(AppDbContext db) => _db = db;

        /// <summary>
        /// The company's rules in evaluation order. Empty for a company that
        /// somehow escaped seeding — callers must treat "no rules" as "plain
        /// barcode lookup only", never as an error.
        /// </summary>
        public async Task<List<BarcodeRuleDto>> GetAllAsync(int companyId, CancellationToken ct = default)
            => await _db.BarcodeRules
                .AsNoTracking()
                .Where(r => r.CompanyId == companyId)
                .OrderBy(r => r.Sequence).ThenBy(r => r.Id)
                .Select(r => new BarcodeRuleDto
                {
                    Id = r.Id,
                    Name = r.Name,
                    Sequence = r.Sequence,
                    Type = r.Type.ToString(),
                    Encoding = r.Encoding.ToString(),
                    Pattern = r.Pattern,
                    IsEnabled = r.IsEnabled
                })
                .ToListAsync(ct);

        /// <summary>
        /// Replaces the company's whole rule set in one transaction.
        /// </summary>
        /// <remarks>
        /// Every pattern is validated BEFORE anything is deleted, so a typo in
        /// row 4 cannot leave the company with no nomenclature at all.
        ///
        /// <see cref="BarcodeRuleDto.Sequence"/> from the client is ignored in
        /// favour of list position: the editor's drag handle reorders the list,
        /// and trusting position removes the chance of two rows claiming the
        /// same sequence and matching in an order nobody chose.
        /// </remarks>
        public async Task<List<BarcodeRuleDto>> ReplaceAllAsync(
            int companyId, IReadOnlyList<BarcodeRuleDto> rules, CancellationToken ct = default)
        {
            var parsed = new List<(string Name, BarcodeRuleType Type, BarcodeEncoding Encoding, string Pattern, bool IsEnabled)>();

            for (var i = 0; i < rules.Count; i++)
            {
                var dto = rules[i];
                var position = i + 1;

                if (string.IsNullOrWhiteSpace(dto.Name))
                    throw new InvalidOperationException($"Rule {position}: name is required.");

                if (!Enum.TryParse<BarcodeRuleType>(dto.Type, ignoreCase: true, out var type))
                    throw new InvalidOperationException(
                        $"Rule '{dto.Name}': unknown type '{dto.Type}'. Expected Unit, Weighted, Priced or Discounted.");

                if (!Enum.TryParse<BarcodeEncoding>(dto.Encoding, ignoreCase: true, out var encoding))
                    throw new InvalidOperationException(
                        $"Rule '{dto.Name}': unknown encoding '{dto.Encoding}'. Expected Any, Ean13 or UpcA.");

                var patternError = ValidatePattern(dto.Pattern, type);
                if (patternError != null)
                    throw new InvalidOperationException($"Rule '{dto.Name}': {patternError}");

                parsed.Add((dto.Name.Trim(), type, encoding, dto.Pattern.Trim(), dto.IsEnabled));
            }

            // 🚨 Inside an execution strategy, and not optionally. The API runs
            // with EnableRetryOnFailure, and SqlServerRetryingExecutionStrategy
            // refuses a hand-rolled BeginTransactionAsync — a retry has to be
            // able to replay the whole unit, which it cannot do around a
            // transaction it did not open. Without this wrapper, saving the
            // nomenclature threw "does not support user-initiated transactions"
            // on every attempt. Replacing the whole set is naturally idempotent,
            // so a replay is safe.
            var strategy = _db.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                await using var tx = await _db.Database.BeginTransactionAsync(ct);

                var existing = await _db.BarcodeRules.Where(r => r.CompanyId == companyId).ToListAsync(ct);
                _db.BarcodeRules.RemoveRange(existing);
                await _db.SaveChangesAsync(ct);

                var sequence = 10;
                foreach (var (name, type, encoding, pattern, isEnabled) in parsed)
                {
                    _db.BarcodeRules.Add(BarcodeRule.Create(companyId, name, sequence, type, encoding, pattern, isEnabled));
                    sequence += 10;
                }

                await _db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
            });

            return await GetAllAsync(companyId, ct);
        }

        /// <summary>
        /// Returns a cashier-readable reason the pattern is unusable, or null.
        /// </summary>
        /// <remarks>
        /// A rule that carries a value (Weighted / Priced / Discounted) is
        /// useless without a placeholder — it would match, contribute a value of
        /// zero, and quietly ring the item up at no charge. That is worth
        /// rejecting at save time rather than discovering at the till.
        /// </remarks>
        public static string? ValidatePattern(string? pattern, BarcodeRuleType type)
        {
            if (string.IsNullOrWhiteSpace(pattern)) return "pattern is required.";

            var trimmed = pattern.Trim();
            var open = trimmed.IndexOf('{');
            var close = trimmed.IndexOf('}');

            if (open < 0 && close < 0)
            {
                return type == BarcodeRuleType.Unit
                    ? null
                    : $"a {type} rule needs an embedded value, e.g. 22.....{{NNDDD}}.";
            }

            if (open < 0 || close < open)
                return "unbalanced braces around the embedded value.";

            if (trimmed.IndexOf('{', open + 1) >= 0)
                return "only one embedded value is supported per pattern.";

            var placeholder = trimmed.Substring(open + 1, close - open - 1);
            if (placeholder.Length == 0)
                return "the embedded value is empty — use N for a digit and D for a decimal digit.";

            if (!placeholder.All(c => c is 'N' or 'n' or 'D' or 'd'))
                return "the embedded value may only contain N and D.";

            if (type == BarcodeRuleType.Unit)
                return "a Unit rule matches a plain barcode and must not embed a value.";

            return null;
        }
    }
}
