using Api.DataBase;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The model and the migration history must describe the same database.
///
/// <para>This is <c>dotnet ef migrations has-pending-model-changes</c>, run by the
/// test suite instead of from memory. It matters because the snapshot is the ONLY
/// record of what the migrations have built up to: a property added to an entity
/// without a migration produces a column the database never gets, and the failure
/// arrives as "Invalid column name" from a live till, not from a build.</para>
///
/// <para>Uses the SQL Server provider deliberately — with no connection, since
/// building a model never opens one. The snapshot is written in SQL Server terms
/// (<c>decimal(18,4)</c>, identity columns), so diffing it under any other
/// provider would report differences that are really just provider translation.</para>
/// </summary>
public class MigrationsMatchTheModelTests
{
    /// <summary>
    /// Drift knowingly left unclosed. <b>There is none</b>, and the number is here so
    /// that staying at zero is a decision rather than an accident.
    ///
    /// <para>It was 1 when this guard was written, for a <c>DropTable:
    /// ProductComment</c> — the entity went with the comment catalogue's retirement
    /// (backlog 43) while the table stayed in SQL Server. That is what EF 10 refuses
    /// to migrate past (<c>PendingModelChangesWarning</c> blocks EVERY
    /// <c>database update</c>, not just one touching that table), so it was closed on
    /// the user's go-ahead by <c>20260909150000_DropProductComment</c>.</para>
    ///
    /// 🚨 Raising this number is how a schema change gets forgotten. Add the
    /// migration instead.
    /// </summary>
    private const int KnownPendingOperations = 0;

    [Fact]
    public void The_snapshot_describes_exactly_what_the_model_describes()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer("Server=(localdb)\\ThisIsNeverConnectedTo;Database=ModelDiffOnly")
            .Options;

        using var db = new AppDbContext(options);

        var snapshot = db.GetService<IMigrationsAssembly>().ModelSnapshot;
        Assert.NotNull(snapshot);

        // A snapshot's model is raw builder output; it has to be finalised the way
        // the runtime finalises the real one before the two can be compared.
        var snapshotModel = db.GetService<IModelRuntimeInitializer>()
            .Initialize(((IMutableModel)snapshot!.Model).FinalizeModel(), designTime: true);

        var differences = db.GetService<IMigrationsModelDiffer>().GetDifferences(
            snapshotModel.GetRelationalModel(),
            db.GetService<IDesignTimeModel>().Model.GetRelationalModel());

        Assert.True(
            differences.Count <= KnownPendingOperations,
            $"The model has {differences.Count} changes no migration accounts for, and only "
            + $"{KnownPendingOperations} are known (see KnownPendingOperations). Add a migration:\n"
            + "  dotnet ef migrations add <Name> --project Web-POS.Api\n"
            + "Operations the differ produced:\n  "
            + string.Join("\n  ", differences.Select(Describe)));
    }

    /// <summary>
    /// Names the operation AND what it would touch — "AlterColumnOperation" on its
    /// own tells you nothing about which column drifted.
    /// </summary>
    private static string Describe(MigrationOperation operation)
    {
        var type = operation.GetType();
        string? Read(string property) => type.GetProperty(property)?.GetValue(operation) as string;

        var target = string.Join(".",
            new[] { Read("Table"), Read("Name") }.Where(s => !string.IsNullOrEmpty(s)));

        return target.Length == 0 ? type.Name : $"{type.Name}: {target}";
    }
}
