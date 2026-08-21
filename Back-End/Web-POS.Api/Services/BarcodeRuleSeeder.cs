using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    /// <summary>
    /// Provisions each company's barcode nomenclature.
    /// </summary>
    /// <remarks>
    /// This supersedes the six single-rule <c>Scale.Barcode.*</c> application
    /// properties. A company that was configured under the old scheme keeps its
    /// behaviour: <see cref="BackfillAsync"/> translates those settings into an
    /// equivalent Weighted rule, so an upgrade does not silently stop decoding
    /// the scale labels already printed on the shelf.
    /// </remarks>
    public static class BarcodeRuleSeeder
    {
        /// <summary>
        /// The out-of-the-box nomenclature, mirroring Odoo's default. Order
        /// matters: the catch-all Unit rule must stay last, or it swallows every
        /// scale label before the weighted rule is ever consulted.
        /// </summary>
        public static readonly (string Name, int Sequence, BarcodeRuleType Type, BarcodeEncoding Encoding, string Pattern)[] Defaults =
        {
            ("Price Barcodes 2 Decimals",  10, BarcodeRuleType.Priced,     BarcodeEncoding.Ean13, "25.....{NNNDD}"),
            ("Weight Barcodes 3 Decimals", 20, BarcodeRuleType.Weighted,   BarcodeEncoding.Ean13, "22.....{NNDDD}"),
            ("Discount Barcodes",          30, BarcodeRuleType.Discounted, BarcodeEncoding.Any,   "22{NN}"),
            ("Product Barcodes",           40, BarcodeRuleType.Unit,       BarcodeEncoding.Any,   ".*"),
        };

        /// <summary>
        /// Gives <paramref name="companyId"/> the default nomenclature if it has
        /// none. Does not call SaveChanges — the caller batches that.
        /// </summary>
        public static async Task SeedAsync(AppDbContext db, int companyId)
        {
            if (await db.BarcodeRules.AnyAsync(r => r.CompanyId == companyId)) return;

            foreach (var (name, sequence, type, encoding, pattern) in Defaults)
                db.BarcodeRules.Add(BarcodeRule.Create(companyId, name, sequence, type, encoding, pattern));
        }

        /// <summary>
        /// Gives every company that predates the nomenclature a rule set, once.
        /// Companies already holding rules are left alone, so this is safe to run
        /// on every startup.
        /// </summary>
        public static async Task BackfillAsync(AppDbContext db)
        {
            var companyIds = await db.Companies.Select(c => c.Id).ToListAsync();
            var configured = await db.BarcodeRules.Select(r => r.CompanyId).Distinct().ToListAsync();
            var todo = companyIds.Except(configured).ToList();
            if (todo.Count == 0) return;

            // The legacy keys, read in one pass rather than per company.
            var legacy = await db.ApplicationProperties
                .Where(p => todo.Contains(p.CompanyId) && p.Name != null && p.Name.StartsWith("Scale.Barcode."))
                .Select(p => new { p.CompanyId, p.Name, p.Value })
                .ToListAsync();

            var byCompany = legacy
                .GroupBy(p => p.CompanyId)
                .ToDictionary(
                    g => g.Key,
                    g => g.ToDictionary(p => p.Name!, p => p.Value, StringComparer.OrdinalIgnoreCase));

            foreach (var companyId in todo)
            {
                foreach (var (name, sequence, type, encoding, pattern) in Defaults)
                    db.BarcodeRules.Add(BarcodeRule.Create(companyId, name, sequence, type, encoding, pattern));

                byCompany.TryGetValue(companyId, out var settings);
                var translated = TranslateLegacyScaleRule(settings);
                if (translated != null)
                {
                    // Sequence 1 so the company's own scale format is tried before
                    // any of the generic defaults can claim the barcode.
                    db.BarcodeRules.Add(BarcodeRule.Create(
                        companyId, "Scale Barcodes (imported)", 1,
                        translated.Value.Type, BarcodeEncoding.Ean13, translated.Value.Pattern));
                }
            }

            await db.SaveChangesAsync();
        }

        /// <summary>
        /// Rebuilds the old prefix/code-length/decimals settings as a pattern.
        /// </summary>
        /// <remarks>
        /// The old parser derived the value width at runtime as "everything
        /// between the product code and the final check digit", which for EAN-13
        /// is <c>13 - prefix - codeLength - 1</c>. Reproducing that arithmetic
        /// here is what makes the imported rule decode the company's existing
        /// labels identically.
        ///
        /// Returns null when the company never enabled scale parsing, or when the
        /// numbers leave no room for a value — in which case the defaults alone
        /// are the honest outcome.
        /// </remarks>
        public static (BarcodeRuleType Type, string Pattern)? TranslateLegacyScaleRule(
            IReadOnlyDictionary<string, string?>? settings)
        {
            if (settings == null) return null;

            string? Read(string key) => settings.TryGetValue(key, out var v) ? v : null;

            if (!string.Equals(Read("Scale.Barcode.Enabled"), "true", StringComparison.OrdinalIgnoreCase))
                return null;

            var prefix = Read("Scale.Barcode.Prefix") ?? string.Empty;
            if (!prefix.All(char.IsDigit)) return null;

            var codeLength = ParseInt(Read("Scale.Barcode.CodeLength"), 5);
            var decimals = ParseInt(Read("Scale.Barcode.DecimalPlaces"), 3);
            var printsPrice = string.Equals(Read("Scale.Barcode.PrintsPrice"), "true", StringComparison.OrdinalIgnoreCase);

            const int Ean13Length = 13;
            var width = Ean13Length - prefix.Length - codeLength - 1; // -1 for the check digit
            if (width <= 0 || codeLength <= 0) return null;
            if (decimals > width) decimals = width;

            var pattern = prefix
                        + new string('.', codeLength)
                        + "{" + new string('N', width - decimals) + new string('D', decimals) + "}";

            return (printsPrice ? BarcodeRuleType.Priced : BarcodeRuleType.Weighted, pattern);
        }

        private static int ParseInt(string? text, int fallback)
            => int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : fallback;
    }
}
