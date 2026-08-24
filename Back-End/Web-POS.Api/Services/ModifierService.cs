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
    /// <summary>
    /// The modifier catalogue: groups, their options, and which products offer
    /// which groups.
    /// </summary>
    /// <remarks>
    /// The three read methods all take <c>modifiedAfter</c> and are what the POS
    /// delta-syncs on. They deliberately do NOT filter out disabled rows: a group
    /// that was just switched off has to reach the till so the till can stop
    /// offering it. Filtering here would leave every device that already cached
    /// it showing it forever.
    ///
    /// 🚨 <b>Deletion does not delta-sync</b>, and that is the house pattern, not
    /// an oversight — nothing in this API has tombstones, so a hard delete only
    /// reaches other devices on a full pull. This is why the admin screen offers
    /// <c>IsEnabled = false</c> as the normal way to retire a group: a disabled
    /// row syncs like any other change and disappears from the till at once.
    /// </remarks>
    public class ModifierService
    {
        private readonly AppDbContext _db;

        public ModifierService(AppDbContext db) => _db = db;

        // ── Reads (delta-synced by the POS) ──────────────────────────────────

        public async Task<List<ModifierGroupDto>> GetGroupsAsync(
            int companyId, DateTime? modifiedAfter, CancellationToken ct = default)
            => await _db.ModifierGroups
                .AsNoTracking()
                .Where(g => g.CompanyId == companyId)
                .Where(g => modifiedAfter == null || g.LastModified > modifiedAfter)
                .OrderBy(g => g.Rank).ThenBy(g => g.Id)
                .Select(g => new ModifierGroupDto
                {
                    Id = g.Id,
                    CompanyId = g.CompanyId,
                    Name = g.Name,
                    MinSelections = g.MinSelections,
                    MaxSelections = g.MaxSelections,
                    AllowsFreeText = g.AllowsFreeText,
                    Rank = g.Rank,
                    IsEnabled = g.IsEnabled,
                    LastModified = g.LastModified
                })
                .ToListAsync(ct);

        public async Task<List<ModifierOptionDto>> GetOptionsAsync(
            int companyId, DateTime? modifiedAfter, CancellationToken ct = default)
            => await _db.ModifierOptions
                .AsNoTracking()
                .Where(o => o.CompanyId == companyId)
                .Where(o => modifiedAfter == null || o.LastModified > modifiedAfter)
                .OrderBy(o => o.ModifierGroupId).ThenBy(o => o.Rank).ThenBy(o => o.Id)
                .Select(o => new ModifierOptionDto
                {
                    Id = o.Id,
                    CompanyId = o.CompanyId,
                    ModifierGroupId = o.ModifierGroupId,
                    Name = o.Name,
                    AdditionalPrice = o.AdditionalPrice,
                    Rank = o.Rank,
                    IsEnabled = o.IsEnabled,
                    LastModified = o.LastModified
                })
                .ToListAsync(ct);

        public async Task<List<ProductModifierGroupDto>> GetProductLinksAsync(
            int companyId, DateTime? modifiedAfter, CancellationToken ct = default)
            => await _db.ProductModifierGroups
                .AsNoTracking()
                .Where(l => l.CompanyId == companyId)
                .Where(l => modifiedAfter == null || l.LastModified > modifiedAfter)
                .OrderBy(l => l.ProductId).ThenBy(l => l.Rank).ThenBy(l => l.Id)
                .Select(l => new ProductModifierGroupDto
                {
                    Id = l.Id,
                    CompanyId = l.CompanyId,
                    ProductId = l.ProductId,
                    ModifierGroupId = l.ModifierGroupId,
                    Rank = l.Rank,
                    LastModified = l.LastModified
                })
                .ToListAsync(ct);

        // ── Writes ───────────────────────────────────────────────────────────
        //
        // 🚨 Every transaction here runs INSIDE an execution strategy, and it is
        // not optional. The API is configured with `EnableRetryOnFailure`, whose
        // `SqlServerRetryingExecutionStrategy` refuses a hand-rolled
        // `BeginTransactionAsync` outright: a retry has to be able to replay the
        // WHOLE unit, and it cannot do that if a transaction it did not open is
        // already in flight. Calling BeginTransaction directly throws
        // "does not support user-initiated transactions" on the first save —
        // which is exactly how this shipped and broke.
        //
        // The body must also be idempotent, because the strategy may run it more
        // than once. All three are: each reads its current state inside the
        // transaction before writing.

        /// <summary>
        /// Creates or updates a group together with its complete option list, in
        /// one transaction. Returns the saved group so an offline client can swap
        /// its temporary negative id for the real one.
        /// </summary>
        /// <remarks>
        /// Options are reconciled, not recreated: an option the request still
        /// carries by id is UPDATED in place. That is load-bearing — the id is
        /// what past sales point at for reporting, so recreating the row would
        /// orphan every <c>DocumentItemModifier</c> that referenced it and break
        /// "how many Extra Cheese did we sell" at the moment somebody renames it.
        /// </remarks>
        public async Task<SavedModifierGroupDto> SaveGroupAsync(
            int companyId, SaveModifierGroupRequest req, CancellationToken ct = default)
        {
            if (companyId <= 0) throw new InvalidOperationException("Company ID is required.");
            if (string.IsNullOrWhiteSpace(req.Name))
                throw new InvalidOperationException("The modifier group needs a name.");

            var cleanOptions = req.Options
                .Where(o => !string.IsNullOrWhiteSpace(o.Name))
                .ToList();

            // A mandatory group with nothing to choose is a product that can
            // never be sold. Caught here rather than at the till.
            if (req.MinSelections > 0 && cleanOptions.Count == 0)
                throw new InvalidOperationException(
                    $"\"{req.Name}\" is mandatory but has no options, so nothing could ever satisfy it.");

            if (req.MinSelections > cleanOptions.Count && cleanOptions.Count > 0)
                throw new InvalidOperationException(
                    $"\"{req.Name}\" asks for at least {req.MinSelections} choices but only has {cleanOptions.Count}.");

            var strategy = _db.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                await using var tx = await _db.Database.BeginTransactionAsync(ct);

                ModifierGroup group;
                if (req.Id > 0)
                {
                    group = await _db.ModifierGroups
                        .FirstOrDefaultAsync(g => g.Id == req.Id && g.CompanyId == companyId, ct)
                        ?? throw new InvalidOperationException($"Modifier group {req.Id} was not found.");

                    group.Update(req.Name, req.MinSelections, req.MaxSelections,
                                 req.AllowsFreeText, req.Rank, req.IsEnabled);
                }
                else
                {
                    group = ModifierGroup.Create(companyId, req.Name, req.MinSelections,
                                                 req.MaxSelections, req.AllowsFreeText,
                                                 req.Rank, req.IsEnabled);
                    _db.ModifierGroups.Add(group);
                }

                await _db.SaveChangesAsync(ct);

                var existing = await _db.ModifierOptions
                    .Where(o => o.ModifierGroupId == group.Id && o.CompanyId == companyId)
                    .ToListAsync(ct);

                var keptIds = new HashSet<int>();

                for (var i = 0; i < cleanOptions.Count; i++)
                {
                    var incoming = cleanOptions[i];
                    var match = incoming.Id > 0
                        ? existing.FirstOrDefault(o => o.Id == incoming.Id)
                        : null;

                    if (match is not null)
                    {
                        match.Update(incoming.Name, incoming.AdditionalPrice, i, incoming.IsEnabled);
                        keptIds.Add(match.Id);
                    }
                    else
                    {
                        _db.ModifierOptions.Add(ModifierOption.Create(
                            companyId, group.Id, incoming.Name, incoming.AdditionalPrice,
                            i, incoming.IsEnabled));
                    }
                }

                var removed = existing.Where(o => !keptIds.Contains(o.Id)).ToList();
                if (removed.Count > 0) _db.ModifierOptions.RemoveRange(removed);

                await _db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);

                // Read the options BACK rather than projecting what was sent:
                // creates only receive their real ids during SaveChanges, and
                // those ids are the whole point of returning them.
                var saved = await _db.ModifierOptions
                    .AsNoTracking()
                    .Where(o => o.ModifierGroupId == group.Id && o.CompanyId == companyId)
                    .OrderBy(o => o.Rank).ThenBy(o => o.Id)
                    .Select(o => new ModifierOptionDto
                    {
                        Id = o.Id,
                        CompanyId = o.CompanyId,
                        ModifierGroupId = o.ModifierGroupId,
                        Name = o.Name,
                        AdditionalPrice = o.AdditionalPrice,
                        Rank = o.Rank,
                        IsEnabled = o.IsEnabled,
                        LastModified = o.LastModified
                    })
                    .ToListAsync(ct);

                return new SavedModifierGroupDto
                {
                    Id = group.Id,
                    CompanyId = group.CompanyId,
                    Name = group.Name,
                    MinSelections = group.MinSelections,
                    MaxSelections = group.MaxSelections,
                    AllowsFreeText = group.AllowsFreeText,
                    Rank = group.Rank,
                    IsEnabled = group.IsEnabled,
                    LastModified = group.LastModified,
                    Options = saved
                };
            });
        }

        /// <summary>Deletes a group, its options, and every product link to it.</summary>
        /// <remarks>
        /// The links are removed explicitly because <c>ProductModifierGroup</c>
        /// deliberately uses <c>NoAction</c> on both foreign keys — SQL Server
        /// refuses multiple cascade paths into that table. The options DO cascade.
        ///
        /// Past sales are untouched: <c>PosOrderItemModifier</c> and
        /// <c>DocumentItemModifier</c> hold snapshots with a nullable, unenforced
        /// option id, so a receipt printed after this still reads correctly.
        /// </remarks>
        public async Task<bool> DeleteGroupAsync(int companyId, int id, CancellationToken ct = default)
        {
            var strategy = _db.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                    // Re-read inside the strategy: on a retry the first attempt may
                    // already have removed it.
                    var group = await _db.ModifierGroups
                        .FirstOrDefaultAsync(g => g.Id == id && g.CompanyId == companyId, ct);
                    if (group is null) return false;

                    await using var tx = await _db.Database.BeginTransactionAsync(ct);

                    var links = await _db.ProductModifierGroups
                        .Where(l => l.ModifierGroupId == id && l.CompanyId == companyId)
                        .ToListAsync(ct);
                    if (links.Count > 0) _db.ProductModifierGroups.RemoveRange(links);

                    _db.ModifierGroups.Remove(group);

                    await _db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);
                    return true;
            });
        }

        /// <summary>
        /// Replaces the set of groups a product offers. List order becomes the
        /// order the sections appear in the cashier's sheet.
        /// </summary>
        /// <remarks>
        /// Reconciled rather than delete-and-recreate so a link that has not moved
        /// keeps its id and its <c>LastModified</c> — otherwise every save would
        /// re-send every link to every till on the next delta pull.
        /// </remarks>
        public async Task<List<ProductModifierGroupDto>> SetProductGroupsAsync(
            int companyId, SetProductModifierGroupsRequest req, CancellationToken ct = default)
        {
            if (req.ProductId <= 0) throw new InvalidOperationException("Product ID is required.");

            var wanted = req.ModifierGroupIds.Where(id => id > 0).Distinct().ToList();

            // A link to a group that does not exist would render as an empty
            // section the cashier cannot satisfy.
            if (wanted.Count > 0)
            {
                var real = await _db.ModifierGroups
                    .Where(g => g.CompanyId == companyId && wanted.Contains(g.Id))
                    .Select(g => g.Id)
                    .ToListAsync(ct);

                var missing = wanted.Except(real).ToList();
                if (missing.Count > 0)
                    throw new InvalidOperationException(
                        $"Modifier group(s) {string.Join(", ", missing)} do not exist for this company.");
            }

            var strategy = _db.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                await using var tx = await _db.Database.BeginTransactionAsync(ct);

                var existing = await _db.ProductModifierGroups
                    .Where(l => l.ProductId == req.ProductId && l.CompanyId == companyId)
                    .ToListAsync(ct);

                for (var i = 0; i < wanted.Count; i++)
                {
                    var match = existing.FirstOrDefault(l => l.ModifierGroupId == wanted[i]);
                    if (match is null)
                    {
                        _db.ProductModifierGroups.Add(
                            ProductModifierGroup.Create(companyId, req.ProductId, wanted[i], i));
                    }
                    else if (match.Rank != i)
                    {
                        match.UpdateRank(i);
                    }
                }

                var removed = existing.Where(l => !wanted.Contains(l.ModifierGroupId)).ToList();
                if (removed.Count > 0) _db.ProductModifierGroups.RemoveRange(removed);

                await _db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
            });

            return await GetProductLinksForProductAsync(companyId, req.ProductId, ct);
        }

        public async Task<List<ProductModifierGroupDto>> GetProductLinksForProductAsync(
            int companyId, int productId, CancellationToken ct = default)
            => await _db.ProductModifierGroups
                .AsNoTracking()
                .Where(l => l.CompanyId == companyId && l.ProductId == productId)
                .OrderBy(l => l.Rank).ThenBy(l => l.Id)
                .Select(l => new ProductModifierGroupDto
                {
                    Id = l.Id,
                    CompanyId = l.CompanyId,
                    ProductId = l.ProductId,
                    ModifierGroupId = l.ModifierGroupId,
                    Rank = l.Rank,
                    LastModified = l.LastModified
                })
                .ToListAsync(ct);
    }
}
