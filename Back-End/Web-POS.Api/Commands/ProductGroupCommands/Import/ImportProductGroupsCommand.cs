using Api.DataBase;
using Api.Domain;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.ProductGroupCommands.Import
{
    public class ImportProductGroupsCommand : IRequest<ImportProductGroupsResult>
    {
        public ImportProductGroupsRequest Request { get; }
        public ImportProductGroupsCommand(ImportProductGroupsRequest request) => Request = request;
    }

    /// <summary>
    /// Creates or merges product groups from a CSV/XML import.
    /// </summary>
    /// <remarks>
    /// Groups are identified by NAME — the server keeps names unique per company —
    /// and placed by their parent's name, so a file exported from one company means
    /// the same thing in another, where no id does.
    ///
    /// Two passes, so rows may come in any order: first every named group is made
    /// to exist, then parents are linked. A parent a row names but no row defines
    /// is created at the root rather than silently dropping the child's place in
    /// the tree. A link that would close a loop (A under B under A) is refused and
    /// reported — the tree walks in the menu and the exports would never end.
    ///
    /// All-or-nothing at the database: the plan is validated first, so the only
    /// failures left are the database's own, and those leave the tree as it was.
    /// </remarks>
    public class ImportProductGroupsCommandHandler
        : IRequestHandler<ImportProductGroupsCommand, ImportProductGroupsResult>
    {
        // Column limits the database enforces (ProductGroup).
        private const int NameMax = 255;
        private const int ColorMax = 50;

        private readonly AppDbContext _db;
        public ImportProductGroupsCommandHandler(AppDbContext db) => _db = db;

        private sealed record PlannedGroup(string Name, string? Parent, string? Color, int? Rank);

        public async Task<ImportProductGroupsResult> Handle(
            ImportProductGroupsCommand command, CancellationToken ct)
        {
            var req = command.Request;
            var result = new ImportProductGroupsResult();

            // ── 1. Rows → one validated plan entry per distinct name ─────────
            var plan = new List<PlannedGroup>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var row in req.Rows)
            {
                var name = Clean(row.Name);
                if (name == null) continue;
                var parent = Clean(row.ParentGroupName);
                var color = Clean(row.Color);

                if (name.Length > NameMax)
                { result.Errors.Add($"'{Short(name)}': the name is longer than {NameMax} characters"); continue; }
                if (parent?.Length > NameMax)
                { result.Errors.Add($"'{Short(name)}': the parent name is longer than {NameMax} characters"); continue; }
                if (color?.Length > ColorMax)
                { result.Errors.Add($"'{Short(name)}': the colour is longer than {ColorMax} characters"); continue; }
                if (parent != null && string.Equals(parent, name, StringComparison.OrdinalIgnoreCase))
                { result.Errors.Add($"'{Short(name)}': a group cannot be its own parent"); continue; }
                if (!seen.Add(name))
                { result.Warnings.Add($"'{Short(name)}': appears more than once — the first row was used"); continue; }

                plan.Add(new PlannedGroup(name, parent, color, row.Rank));
            }

            if (plan.Count == 0) return result;

            // ── 2. Apply, all or nothing ─────────────────────────────────────
            var created = new List<object>();
            var touched = new List<ProductGroup>();
            ImportProductGroupsResult? applied = null;
            var attempted = false;

            try
            {
                await _db.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
                {
                    // A retried attempt must not inherit the failed one's changes.
                    if (attempted) await RollBackAsync(created, touched, ct);
                    attempted = true;

                    await using var tx = await _db.Database.BeginTransactionAsync(ct);
                    applied = await ApplyAsync(plan, req, created, touched, ct);
                    await tx.CommitAsync(ct);
                });
            }
            catch (Exception ex)
            {
                await RollBackAsync(created, touched, ct);
                result.Errors.Add($"The import could not be saved, nothing was changed: {Innermost(ex).Message}");
                return result;
            }

            result.Created = applied!.Created;
            result.Updated = applied.Updated;
            result.Skipped = applied.Skipped;
            result.Errors.AddRange(applied.Errors);
            result.Warnings.AddRange(applied.Warnings);
            return result;
        }

        private async Task<ImportProductGroupsResult> ApplyAsync(
            List<PlannedGroup> plan,
            ImportProductGroupsRequest req,
            List<object> created,
            List<ProductGroup> touched,
            CancellationToken ct)
        {
            var r = new ImportProductGroupsResult();
            var companyId = req.CompanyId;

            var groups = (await _db.ProductGroups.Where(g => g.CompanyId == companyId).ToListAsync(ct))
                .GroupBy(g => Key(g.Name))
                .ToDictionary(g => g.Key, g => g.OrderBy(x => x.Id).First());

            // Rows the import must not touch at all, parent included.
            var untouchable = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            // Pass 1 — every named group exists.
            foreach (var p in plan)
            {
                if (groups.TryGetValue(Key(p.Name), out var existing))
                {
                    if (req.SkipDuplicates || !req.MergeDuplicates)
                    {
                        r.Skipped++;
                        untouchable.Add(p.Name);
                        continue;
                    }

                    Track(touched, existing);
                    existing.Update(existing.Name, existing.ParentGroupId,
                        p.Color ?? existing.Color, existing.Image, p.Rank ?? existing.Rank, companyId);
                    r.Updated++;
                }
                else
                {
                    var group = ProductGroup.Create(p.Name, null, p.Color ?? "Transparent", null, p.Rank ?? 0, companyId);
                    _db.ProductGroups.Add(group);
                    created.Add(group);
                    groups[Key(p.Name)] = group;
                    r.Created++;
                }
            }

            // A parent a row names but neither the file nor the company has: made at
            // the root, so the child still gets its place in the tree.
            foreach (var parentName in plan
                         .Where(p => p.Parent != null && !untouchable.Contains(p.Name))
                         .Select(p => p.Parent!)
                         .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                if (groups.ContainsKey(Key(parentName))) continue;
                var group = ProductGroup.Create(parentName, null, "Transparent", null, 0, companyId);
                _db.ProductGroups.Add(group);
                created.Add(group);
                groups[Key(parentName)] = group;
                r.Created++;
                r.Warnings.Add($"'{Short(parentName)}': created because a row names it as a parent");
            }

            await _db.SaveChangesAsync(ct); // ids, so parents can be linked

            // Pass 2 — parents. A blank parent says nothing, so it never moves an
            // existing group to the root; only a named parent moves anything.
            var parentOf = groups.Values.ToDictionary(g => g.Id, g => g.ParentGroupId);
            foreach (var p in plan)
            {
                if (p.Parent == null || untouchable.Contains(p.Name)) continue;

                var child = groups[Key(p.Name)];
                var parent = groups[Key(p.Parent)];
                if (child.ParentGroupId == parent.Id) continue;

                if (WouldLoop(child.Id, parent.Id, parentOf))
                {
                    r.Errors.Add($"'{Short(p.Name)}': putting it under '{Short(p.Parent)}' would make a loop — left where it was");
                    continue;
                }

                if (!created.Contains(child)) Track(touched, child);
                child.Update(child.Name, parent.Id, child.Color, child.Image, child.Rank, companyId);
                parentOf[child.Id] = parent.Id;
            }

            await _db.SaveChangesAsync(ct);
            return r;
        }

        /// <summary>True when <paramref name="newParentId"/> is the child itself or
        /// already sits somewhere beneath it.</summary>
        private static bool WouldLoop(int childId, int newParentId, Dictionary<int, int?> parentOf)
        {
            var steps = 0;
            for (int? at = newParentId; at != null && steps <= parentOf.Count; steps++)
            {
                if (at == childId) return true;
                at = parentOf.GetValueOrDefault(at.Value);
            }
            return false;
        }

        private async Task RollBackAsync(List<object> created, List<ProductGroup> touched, CancellationToken ct)
        {
            foreach (var entity in created) _db.Entry(entity).State = EntityState.Detached;
            foreach (var group in touched)
            {
                var entry = _db.Entry(group);
                if (entry.State != EntityState.Detached) await entry.ReloadAsync(ct);
            }
            created.Clear();
            touched.Clear();
        }

        private static void Track(List<ProductGroup> touched, ProductGroup group)
        {
            if (!touched.Contains(group)) touched.Add(group);
        }

        private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

        private static string Key(string s) => s.Trim().ToLowerInvariant();

        private static string Short(string s) => s.Length > 60 ? s[..60] + "…" : s;

        private static Exception Innermost(Exception ex)
        {
            while (ex.InnerException != null) ex = ex.InnerException;
            return ex;
        }
    }
}
