using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace Api.Services;

/// <summary>
/// Orders a set of tables so that every table is deleted BEFORE the tables it
/// references. That lets a company purge run with foreign-key enforcement left
/// ON.
///
/// This replaces the previous approach, which disabled every constraint
/// (<c>ALTER TABLE … NOCHECK CONSTRAINT ALL</c>), deleted in arbitrary order,
/// then re-armed with <c>WITH CHECK CHECK CONSTRAINT ALL</c>. That worked, but
/// it required ALTER on ~50 tables, so the API's runtime login needed schema
/// rights it otherwise has no use for. On the production server that login is
/// deliberately only <c>db_datareader</c> + <c>db_datawriter</c>, so the toggle
/// failed outright with "Cannot find the object … or you do not have
/// permissions."
///
/// Deleting in dependency order needs no rights beyond DELETE. It is also
/// strictly safer: constraints are never off, so a bug cannot leave orphans
/// behind, and a genuine referential mistake surfaces immediately on the
/// offending DELETE instead of at the far end on the re-enable — after the data
/// is already gone.
/// </summary>
public static class ForeignKeyDeleteOrder
{
    /// <summary>
    /// Topologically sorts <paramref name="tables"/> children-first, given the
    /// foreign keys between them. An edge is (Child, Parent), meaning "Child has
    /// a FK pointing at Parent", so Child must be emptied first.
    ///
    /// Pure and database-free so it can be tested without SQL Server — the test
    /// suite runs on SQLite, which has no <c>sys.foreign_keys</c>.
    ///
    /// Edges touching a table outside <paramref name="tables"/> are ignored: a
    /// caller resetting a subset only has to order what it is actually deleting.
    /// Self-references are ignored too (see the ProductGroup note below).
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// The graph contains a cycle, so no safe order exists. Thrown rather than
    /// guessed at — the previous code could not hit this because it simply
    /// switched the constraints off.
    /// </exception>
    public static List<string> Resolve(
        IEnumerable<string> tables,
        IEnumerable<(string Child, string Parent)> edges)
    {
        // Sorted so the output is deterministic when several tables are equally
        // free to go. Ties would otherwise fall out of hash ordering and make
        // the emitted order vary between runs, which is miserable to debug.
        var remaining = new SortedSet<string>(tables, StringComparer.OrdinalIgnoreCase);

        // parents[t] = tables t points AT. children[t] = tables pointing at t.
        var parents = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
        var children = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
        foreach (var t in remaining)
        {
            parents[t] = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            children[t] = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        }

        foreach (var (child, parent) in edges)
        {
            // A self-reference (ProductGroup.ParentId → ProductGroup) cannot be
            // ordered around, and does not need to be: one
            // `DELETE … WHERE CompanyId = @cid` removes the whole hierarchy in a
            // single statement, and SQL Server validates the FK once the
            // statement completes rather than row by row.
            if (string.Equals(child, parent, StringComparison.OrdinalIgnoreCase)) continue;
            if (!remaining.Contains(child) || !remaining.Contains(parent)) continue;

            parents[child].Add(parent);
            children[parent].Add(child);
        }

        // Kahn's algorithm. A table is safe to delete once nothing still to be
        // deleted references it, i.e. it has no remaining children.
        var order = new List<string>(remaining.Count);
        var ready = new SortedSet<string>(
            remaining.Where(t => children[t].Count == 0), StringComparer.OrdinalIgnoreCase);

        while (ready.Count > 0)
        {
            var next = ready.Min!;
            ready.Remove(next);
            order.Add(next);

            foreach (var parent in parents[next])
            {
                children[parent].Remove(next);
                if (children[parent].Count == 0) ready.Add(parent);
            }
        }

        if (order.Count != remaining.Count)
        {
            var stuck = remaining.Except(order, StringComparer.OrdinalIgnoreCase).OrderBy(x => x);
            throw new InvalidOperationException(
                "Cannot order these tables for deletion: their foreign keys form a cycle (" +
                string.Join(", ", stuck) + "). Break the cycle with a nullable FK that is " +
                "cleared first, the way Booking.PosOrderId is.");
        }

        return order;
    }

    /// <summary>
    /// Reads the foreign keys between <paramref name="tables"/> from SQL Server
    /// and returns them in delete order.
    ///
    /// Reading <c>sys.foreign_keys</c> needs no special grant — catalogue views
    /// only reveal objects the caller already has permission on, and
    /// <c>db_datareader</c> covers every table here.
    /// </summary>
    public static async Task<List<string>> ResolveAsync(
        DatabaseFacade database, IEnumerable<string> tables)
    {
        var wanted = tables.ToList();
        if (wanted.Count == 0) return [];

        // Returned as one delimited string per row rather than a two-column
        // projection: EF's SqlQueryRaw<T> maps scalars without ceremony, and the
        // codebase already reads sys.tables this way. '>' cannot occur in a
        // table name, so the split is unambiguous.
        var raw = await database
            .SqlQueryRaw<string>(@"
                SELECT DISTINCT OBJECT_NAME(fk.parent_object_id) + '>' +
                                OBJECT_NAME(fk.referenced_object_id) AS Value
                FROM sys.foreign_keys fk
                WHERE fk.parent_object_id <> fk.referenced_object_id")
            .ToListAsync();

        var edges = raw
            .Select(s => s.Split('>', 2))
            .Where(p => p.Length == 2)
            .Select(p => (Child: p[0], Parent: p[1]));

        return Resolve(wanted, edges);
    }

    /// <summary>
    /// Rejects anything that is not a plain SQL identifier. Table names have to
    /// be interpolated into the DELETE (they cannot be parameters), so they are
    /// proven safe rather than assumed safe. Every name reaching here comes from
    /// a hardcoded array or from sys.tables, never from a request — this is the
    /// belt to that braces.
    /// </summary>
    public static void AssertSafeIdentifier(string name)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(name, @"^[A-Za-z][A-Za-z0-9_]*$"))
        {
            throw new InvalidOperationException(
                $"Refusing to build SQL for unsafe table name '{name}'.");
        }
    }
}
