using Api.DataBase;
using Api.Startup;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The boot-time reconciliation of <c>HasTrigger</c> declarations against
/// <c>sys.triggers</c>.
///
/// <para>Why it is worth pinning: a trigger declaration is the one piece of the model
/// EF never validates. It does not resolve the name, it does not check the trigger
/// exists — it only stops emitting an OUTPUT clause on writes to that table. So the
/// model can claim a trigger that has never existed (it did, for four tables, for
/// years, and one of those claims left an unanswerable "does a refund restock twice?"
/// comment sitting in ProcessRefundCommand) and nothing anywhere says so.</para>
///
/// <para>The comparison is deliberately pure, so these tests pin the LOGIC rather than
/// whatever the SQL Server on the machine running them happens to hold. The one test
/// that touches the real model builds it on SQLite — the model is provider-independent
/// here, and no database is created.</para>
/// </summary>
public class TriggerReconciliationTests
{
    private static (string, string) Pair(string table, string trigger) => (table, trigger);

    [Fact]
    public void Clean_when_model_and_database_agree()
    {
        var report = TriggerReconciliation.Compare(
            declared: [Pair("Document", "trg_Document_CompanyConsistency")],
            actual:   [Pair("Document", "trg_Document_CompanyConsistency")]);

        Assert.True(report.IsClean);
        Assert.Empty(report.Undeclared);
        Assert.Empty(report.Misnamed);
    }

    /// <summary>
    /// The direction that BREAKS WRITES: SQL Server rejects an OUTPUT clause on a table
    /// with an enabled trigger (error 334), so an undeclared trigger fails every insert
    /// into that table. This is the finding the check exists for.
    /// </summary>
    [Fact]
    public void Flags_a_trigger_the_model_does_not_declare()
    {
        var report = TriggerReconciliation.Compare(
            declared: [],
            actual:   [Pair("Stock", "trg_Stock_Audit")]);

        var finding = Assert.Single(report.Undeclared);
        Assert.Equal("Stock", finding.Table);
        Assert.Equal("trg_Stock_Audit", Assert.Single(finding.Names));
        Assert.False(report.IsClean);
    }

    /// <summary>
    /// The four phantoms are deliberate, so they must NOT warn — a warning on every
    /// boot for a known-good state is how a real one stops being read.
    /// </summary>
    [Fact]
    public void Known_phantoms_are_reported_but_do_not_break_a_clean_run()
    {
        var report = TriggerReconciliation.Compare(
            declared: [Pair("DocumentItem", "DocumentItem_Insert_Trigger")],
            actual:   []);

        Assert.True(report.IsClean);
        Assert.Empty(report.UnexpectedPhantoms);
        Assert.Equal("DocumentItem", Assert.Single(report.DeliberatePhantoms).Table);
    }

    [Fact]
    public void Flags_a_phantom_nobody_signed_off_on()
    {
        var report = TriggerReconciliation.Compare(
            declared: [Pair("Product", "Product_Insert_Trigger")],
            actual:   []);

        Assert.False(report.IsClean);
        Assert.Equal("Product", Assert.Single(report.UnexpectedPhantoms).Table);
        Assert.Empty(report.DeliberatePhantoms);
    }

    /// <summary>
    /// Writes stay correct here — EF only needs to know that <i>a</i> trigger exists —
    /// but the name in the model is fiction, which is the failure this whole check was
    /// written after.
    /// </summary>
    [Fact]
    public void Flags_a_name_that_does_not_match_the_real_trigger()
    {
        var report = TriggerReconciliation.Compare(
            declared: [Pair("Barcode", "Barcode_Insert_Trigger")],
            actual:   [Pair("Barcode", "trg_Barcode_CompanyMatch")]);

        var finding = Assert.Single(report.Misnamed);
        Assert.Equal("Barcode", finding.Table);
        Assert.Equal("Barcode_Insert_Trigger", Assert.Single(finding.Declared));
        Assert.Equal("trg_Barcode_CompanyMatch", Assert.Single(finding.Actual));
        Assert.False(report.IsClean);
    }

    /// <summary>
    /// One declaration covers a table with several triggers — EF suppresses the OUTPUT
    /// clause for the table, not per trigger — so naming one of them is not a mismatch.
    /// </summary>
    [Fact]
    public void A_table_with_several_triggers_needs_only_one_of_them_named()
    {
        var report = TriggerReconciliation.Compare(
            declared: [Pair("Document", "trg_Document_CompanyConsistency")],
            actual:
            [
                Pair("Document", "trg_Document_CompanyConsistency"),
                Pair("Document", "trg_Document_Audit")
            ]);

        Assert.True(report.IsClean);
        Assert.Empty(report.Misnamed);
    }

    /// <summary>SQL Server's default collation is case-insensitive; the check must be too.</summary>
    [Fact]
    public void Table_and_trigger_names_compare_case_insensitively()
    {
        var report = TriggerReconciliation.Compare(
            declared: [Pair("document", "TRG_Document_CompanyConsistency")],
            actual:   [Pair("Document", "trg_document_companyconsistency")]);

        Assert.True(report.IsClean);
        Assert.Empty(report.Undeclared);
        Assert.Empty(report.UnexpectedPhantoms);
    }

    /// <summary>
    /// Keeps the deliberate-phantom list honest. If a declaration is ever deleted from
    /// AppDbContext, its name here becomes a lie of the same kind the check hunts — a
    /// entry that quietly suppresses a warning for a table that no longer claims
    /// anything.
    /// </summary>
    [Fact]
    public void Every_deliberate_phantom_is_still_declared_by_the_model()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite("DataSource=:memory:")
            .Options;

        using var db = new AppDbContext(options);
        var declaredTables = TriggerReconciliation.DeclaredIn(db.Model)
            .Select(d => d.Table)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        foreach (var phantom in TriggerReconciliation.DeliberatePhantomTables)
            Assert.Contains(phantom, declaredTables);
    }

    /// <summary>
    /// The three REAL triggers, verified against sys.triggers on 2026-09-09 and scripted
    /// in <c>DataBase/SQL/trg_*.sql</c>. Dropping a declaration here is not a tidy-up:
    /// it fails every insert into that table with SQL error 334.
    /// </summary>
    [Theory]
    [InlineData("Document")]
    [InlineData("FloorPlanTable")]
    [InlineData("Barcode")]
    public void The_tables_carrying_a_real_trigger_are_declared(string table)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite("DataSource=:memory:")
            .Options;

        using var db = new AppDbContext(options);

        Assert.Contains(
            TriggerReconciliation.DeclaredIn(db.Model),
            d => string.Equals(d.Table, table, StringComparison.OrdinalIgnoreCase));
    }
}
