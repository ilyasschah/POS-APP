using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace Api.Startup;

/// <summary>
/// Compares the <c>HasTrigger</c> declarations in <see cref="Api.DataBase.AppDbContext"/>
/// against <c>sys.triggers</c> on every boot.
///
/// <para>Why this exists: a comment in <c>ProcessRefundCommand</c> asked for over a
/// year whether <c>DocumentItem_Insert_Trigger</c> also moved stock for a refund —
/// i.e. whether every refund restocked twice. Nobody could answer it from the repo,
/// because the model is the only place a trigger's name appears and EF never resolves
/// that name against anything. It took a hand-run query on the live database to settle
/// it (2026-09-01: the trigger has never existed). This turns that one manual probe
/// into something every environment answers for itself, out loud, on every start.</para>
///
/// <para>What EF actually does with a declaration: it stops emitting an <c>OUTPUT</c>
/// clause on writes to that table. Only the *existence* of a declaration matters — the
/// name is a label for humans and nothing more. That is what makes both directions of
/// drift possible without anything visibly breaking:</para>
/// <list type="bullet">
///   <item><b>Undeclared</b> (real trigger, silent model) — <b>fatal to writes</b>.
///     SQL Server rejects an <c>OUTPUT</c> clause on a table carrying an enabled
///     trigger (error 334), so every insert into that table throws from the moment
///     the trigger is created.</item>
///   <item><b>Phantom</b> (declaration, no trigger) — costs the slower write path and
///     nothing else, but the invented name reads as fact to the next person.</item>
///   <item><b>Misnamed</b> (both sides real, names disagree) — writes are correct; the
///     name in the model is fiction.</item>
/// </list>
/// </summary>
public static class TriggerReconciliation
{
    /// <summary>
    /// The four phantom declarations that are there on purpose, kept out of the
    /// warning path so a healthy boot stays quiet.
    ///
    /// <para>None of these triggers has ever existed. They are DELIBERATELY left
    /// (decision recorded in <c>PROJECT_DOCUMENTATION.md</c> §6, UPGRADE-1): a
    /// declaration too many only costs the slower insert path, while a declaration
    /// too few breaks every insert into the table with SQL error 334 the day someone
    /// adds a trigger to it. Deleting one is a real decision, not a tidy-up — the
    /// pay-off is a faster write path on <c>DocumentItem</c> and <c>Payment</c>, the
    /// two hottest write tables in the app.</para>
    ///
    /// 🚨 Removing a name from this set does NOT remove the declaration. This set only
    /// governs the log level; the declaration lives in <c>AppDbContext.OnModelCreating</c>.
    /// </summary>
    public static readonly IReadOnlySet<string> DeliberatePhantomTables =
        new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "DocumentItem", "Booking", "Payment", "StartingCash"
        };

    /// <summary>A table and the trigger names on one side of the comparison.</summary>
    public sealed record TableTriggers(string Table, IReadOnlyList<string> Names)
    {
        public override string ToString() => $"{Table} ({string.Join(", ", Names)})";
    }

    /// <summary>A table whose declared and actual trigger names have nothing in common.</summary>
    public sealed record NameMismatch(
        string Table, IReadOnlyList<string> Declared, IReadOnlyList<string> Actual)
    {
        public override string ToString() =>
            $"{Table} (model says {string.Join(", ", Declared)}; database has {string.Join(", ", Actual)})";
    }

    /// <summary>
    /// The whole finding. Empty lists everywhere means model and database agree.
    /// </summary>
    public sealed record Report
    {
        /// <summary>Enabled triggers the model knows nothing about — writes to these tables FAIL.</summary>
        public IReadOnlyList<TableTriggers> Undeclared { get; init; } = [];

        /// <summary>Declared, does not exist, and not on the deliberate list — someone invented a name.</summary>
        public IReadOnlyList<TableTriggers> UnexpectedPhantoms { get; init; } = [];

        /// <summary>Declared, does not exist, and known to be deliberate.</summary>
        public IReadOnlyList<TableTriggers> DeliberatePhantoms { get; init; } = [];

        /// <summary>Both sides carry triggers, but not one name matches.</summary>
        public IReadOnlyList<NameMismatch> Misnamed { get; init; } = [];

        /// <summary>True when nothing needs saying — the deliberate phantoms do not count.</summary>
        public bool IsClean =>
            Undeclared.Count == 0 && UnexpectedPhantoms.Count == 0 && Misnamed.Count == 0;
    }

    /// <summary>
    /// Only <c>parent_class = 1</c> (a trigger on a table, not on the database or
    /// server) and only enabled ones: a disabled trigger does not block the
    /// <c>OUTPUT</c> clause, so it is not the model's business.
    /// </summary>
    private const string TriggerQuery = """
        SELECT OBJECT_NAME(t.parent_id) + '|' + t.name AS Value
        FROM sys.triggers AS t
        WHERE t.parent_class = 1 AND t.is_disabled = 0
        """;

    /// <summary>Every trigger the model declares, as (table, trigger name) pairs.</summary>
    public static IReadOnlyList<(string Table, string Trigger)> DeclaredIn(IModel model) =>
        model.GetRelationalModel().Tables
            .SelectMany(t => t.Triggers.Select(
                trigger => (t.Name, trigger.GetDatabaseName() ?? trigger.ModelName)))
            .ToList();

    /// <summary>Every enabled table trigger the database actually carries.</summary>
    public static async Task<IReadOnlyList<(string Table, string Trigger)>> ActualInAsync(
        DbContext db, CancellationToken ct = default)
    {
        var rows = await db.Database.SqlQueryRaw<string>(TriggerQuery).ToListAsync(ct);

        return rows
            .Select(r => r.Split('|', 2))
            .Where(parts => parts.Length == 2)
            .Select(parts => (parts[0], parts[1]))
            .ToList();
    }

    /// <summary>
    /// The comparison itself — pure, so it is pinned by tests rather than by whatever
    /// the database on this machine happens to hold.
    ///
    /// Matching is per TABLE, never per name, because that is what EF cares about: one
    /// declaration on a table with three triggers is enough, and a declaration whose
    /// name is wrong still suppresses the OUTPUT clause correctly.
    /// </summary>
    public static Report Compare(
        IEnumerable<(string Table, string Trigger)> declared,
        IEnumerable<(string Table, string Trigger)> actual)
    {
        var byDeclared = Group(declared);
        var byActual   = Group(actual);

        var phantoms = byDeclared
            .Where(kv => !byActual.ContainsKey(kv.Key))
            .Select(kv => new TableTriggers(kv.Key, kv.Value))
            .ToList();

        return new Report
        {
            Undeclared = byActual
                .Where(kv => !byDeclared.ContainsKey(kv.Key))
                .Select(kv => new TableTriggers(kv.Key, kv.Value))
                .ToList(),

            DeliberatePhantoms = phantoms
                .Where(p => DeliberatePhantomTables.Contains(p.Table))
                .ToList(),

            UnexpectedPhantoms = phantoms
                .Where(p => !DeliberatePhantomTables.Contains(p.Table))
                .ToList(),

            Misnamed = byDeclared
                .Where(kv => byActual.ContainsKey(kv.Key)
                          && !kv.Value.Intersect(byActual[kv.Key], StringComparer.OrdinalIgnoreCase).Any())
                .Select(kv => new NameMismatch(kv.Key, kv.Value, byActual[kv.Key]))
                .ToList()
        };
    }

    /// <summary>
    /// Runs the comparison and says what it found. Never throws: this is a diagnostic,
    /// and a database that will not answer a <c>sys.triggers</c> query must not stop
    /// the API from serving.
    /// </summary>
    public static async Task VerifyAsync(DbContext db, ILogger logger, CancellationToken ct = default)
    {
        // SQL Server only — sys.triggers does not exist on the SQLite provider the
        // tests run the model against.
        if (!db.Database.IsSqlServer()) return;

        Report report;
        try
        {
            report = Compare(DeclaredIn(db.Model), await ActualInAsync(db, ct));
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Trigger declarations could not be checked against sys.triggers.");
            return;
        }

        foreach (var t in report.Undeclared)
        {
            logger.LogError(
                "TRIGGER NOT DECLARED IN THE MODEL: {trigger}. SQL Server refuses an OUTPUT " +
                "clause on a table carrying an enabled trigger (error 334), so EVERY insert " +
                "into this table now fails. Fix: add .ToTable(t => t.HasTrigger(\"...\")) for " +
                "this entity in AppDbContext.OnModelCreating, or disable the trigger.", t);
        }

        foreach (var t in report.UnexpectedPhantoms)
        {
            logger.LogWarning(
                "Model declares a trigger that does not exist: {trigger}. Writes are correct — " +
                "it only costs the slower no-OUTPUT insert path — but the name is fiction, and " +
                "a name in the model is read as a fact about the database.", t);
        }

        foreach (var m in report.Misnamed)
        {
            logger.LogWarning(
                "Trigger name in the model does not match the database: {mismatch}. Writes are " +
                "correct (EF only needs to know that a trigger exists), but the name is wrong.", m);
        }

        if (report.IsClean)
        {
            logger.LogDebug(
                "Trigger declarations reconciled against sys.triggers ({phantoms} deliberate phantom(s)).",
                report.DeliberatePhantoms.Count);
        }
    }

    private static SortedDictionary<string, IReadOnlyList<string>> Group(
        IEnumerable<(string Table, string Trigger)> pairs)
    {
        var grouped = new SortedDictionary<string, IReadOnlyList<string>>(StringComparer.OrdinalIgnoreCase);

        foreach (var group in pairs.GroupBy(p => p.Table, StringComparer.OrdinalIgnoreCase))
            grouped[group.Key] = group.Select(p => p.Trigger).OrderBy(n => n, StringComparer.OrdinalIgnoreCase).ToList();

        return grouped;
    }
}
