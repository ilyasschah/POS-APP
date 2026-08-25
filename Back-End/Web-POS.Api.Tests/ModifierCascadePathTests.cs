using System.Linq;
using Api.DataBase;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace Api.Tests;

/// <summary>
/// SQL Server error 1785 — "may cause cycles or multiple cascade paths" — caught
/// in the build instead of at the customer's database.
/// </summary>
/// <remarks>
/// This shipped once. <c>CompanyId</c> is a non-nullable int, so EF's DEFAULT
/// delete behaviour for it is CASCADE, and nothing in the entity class says so:
/// the modifier tables each got a silent <c>Company → … ON DELETE CASCADE</c>
/// alongside their real parent, which gave <c>ModifierOption</c> two paths in
/// (<c>Company → ModifierOption</c> and <c>Company → ModifierGroup →
/// ModifierOption</c>) and SQL Server refused the entire migration.
///
/// The failure mode is what makes it worth a test: EF builds the model happily,
/// <c>dotnet build</c> passes, the migration file generates, and the error only
/// appears when somebody runs the SQL against a real server — by which point it
/// is a deploy that had to be abandoned.
///
/// These walk the built model rather than the generated SQL, so they cover
/// every future entity, not just the one that bit.
/// </remarks>
public class ModifierCascadePathTests
{
    /// <summary>
    /// The model, built without touching a database. `context.Model` is
    /// constructed lazily from the configuration alone — no connection is
    /// opened, so the fake connection string is never used.
    /// </summary>
    private static IModel BuildModel()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer("Server=(unused);Database=(unused);Trusted_Connection=True;")
            .Options;

        using var context = new AppDbContext(options);
        return context.Model;
    }

    private static readonly string[] ModifierTables =
    [
        "ModifierGroup",
        "ModifierOption",
        "ProductModifierGroup",
        "PosOrderItemModifier",
        "DocumentItemModifier"
    ];

    [Fact]
    public void No_modifier_table_has_more_than_one_incoming_cascade()
    {
        // The rule SQL Server actually enforces, stated directly. Two parents
        // both cascading into one table is what error 1785 rejects.
        var model = BuildModel();
        var offenders = new List<string>();

        foreach (var name in ModifierTables)
        {
            var entity = model.GetEntityTypes()
                .FirstOrDefault(e => e.GetTableName() == name);
            Assert.NotNull(entity);

            var cascades = entity!.GetForeignKeys()
                .Where(fk => fk.DeleteBehavior == DeleteBehavior.Cascade)
                .Select(fk => fk.PrincipalEntityType.GetTableName())
                .ToList();

            if (cascades.Count > 1)
                offenders.Add($"{name} ← cascade from {string.Join(" AND ", cascades)}");
        }

        Assert.True(offenders.Count == 0,
            "SQL Server will refuse this migration with error 1785. Pin the extra "
            + "relationship to DeleteBehavior.NoAction in AppDbContext:\n  "
            + string.Join("\n  ", offenders));
    }

    [Fact]
    public void The_company_link_never_cascades_on_a_modifier_table()
    {
        // The specific trap: it is a DEFAULT, not something anyone wrote, so it
        // is invisible in the entity class and easy to reintroduce.
        var model = BuildModel();
        var offenders = new List<string>();

        foreach (var name in ModifierTables)
        {
            var entity = model.GetEntityTypes()
                .FirstOrDefault(e => e.GetTableName() == name);

            var companyFk = entity?.GetForeignKeys()
                .FirstOrDefault(fk => fk.PrincipalEntityType.GetTableName() == "Company");

            if (companyFk?.DeleteBehavior == DeleteBehavior.Cascade)
                offenders.Add(name);
        }

        Assert.True(offenders.Count == 0,
            "CompanyId is a non-nullable int, so EF defaults it to CASCADE. These "
            + "need an explicit .OnDelete(DeleteBehavior.NoAction) — deleting a "
            + "Company row is not how a company's data is removed "
            + "(CompanyDataResetService does that explicitly):\n  "
            + string.Join("\n  ", offenders));
    }

    [Fact]
    public void The_cascades_we_DO_want_are_still_there()
    {
        // The other half: fixing 1785 by removing every cascade would leave
        // orphaned options and orphaned line snapshots behind forever.
        var model = BuildModel();

        (string Child, string Parent)[] expected =
        [
            ("ModifierOption", "ModifierGroup"),
            ("PosOrderItemModifier", "PosOrderItem"),
            ("DocumentItemModifier", "DocumentItem")
        ];

        foreach (var (child, parent) in expected)
        {
            var entity = model.GetEntityTypes()
                .FirstOrDefault(e => e.GetTableName() == child);
            Assert.NotNull(entity);

            var fk = entity!.GetForeignKeys()
                .FirstOrDefault(f => f.PrincipalEntityType.GetTableName() == parent);
            Assert.NotNull(fk);

            Assert.True(fk!.DeleteBehavior == DeleteBehavior.Cascade,
                $"{child} must still cascade from {parent}, or deleting a "
                + $"{parent} leaves orphans behind.");
        }
    }

    [Fact]
    public void A_line_snapshot_never_points_at_the_catalogue_option()
    {
        // The snapshot rule, enforced by the absence of a relationship rather
        // than by convention: a foreign key to ModifierOption would block
        // deleting an option that any past sale referenced, and cascading it
        // would delete the history instead.
        var model = BuildModel();

        foreach (var name in new[] { "PosOrderItemModifier", "DocumentItemModifier" })
        {
            var entity = model.GetEntityTypes()
                .FirstOrDefault(e => e.GetTableName() == name);
            Assert.NotNull(entity);

            Assert.DoesNotContain(
                entity!.GetForeignKeys(),
                fk => fk.PrincipalEntityType.GetTableName() == "ModifierOption");
        }
    }
}
