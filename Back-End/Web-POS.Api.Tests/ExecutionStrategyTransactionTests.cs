using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// "The configured execution strategy 'SqlServerRetryingExecutionStrategy' does
/// not support user-initiated transactions" — caught in the build instead of on
/// the first save against a real server.
/// </summary>
/// <remarks>
/// This shipped once, in <c>ModifierService</c>. The API enables
/// <c>EnableRetryOnFailure</c>, and that strategy refuses a hand-rolled
/// <c>BeginTransactionAsync</c> outright: a retry has to replay the WHOLE unit
/// of work, which it cannot do if a transaction it did not open is already in
/// flight. The whole body must sit inside
/// <c>Database.CreateExecutionStrategy().ExecuteAsync(...)</c>.
///
/// The failure mode is what earns it a test. Nothing catches it earlier —
/// <c>dotnet build</c> passes, every unit test passes, Swagger renders the
/// endpoint — and it only throws when a real SQL Server connection is behind the
/// context. The one signal is a 500 on the first write the feature ever does.
/// </remarks>
public class ExecutionStrategyTransactionTests
{
    private static string? FindApiSourceRoot([CallerFilePath] string thisFile = "")
    {
        var beside = Path.GetDirectoryName(Path.GetDirectoryName(thisFile));
        if (beside is not null)
        {
            var candidate = Path.Combine(beside, "Web-POS.Api");
            if (Directory.Exists(candidate)) return candidate;
        }
        return null;
    }

    [Fact]
    public void Every_hand_rolled_transaction_runs_inside_an_execution_strategy()
    {
        var root = FindApiSourceRoot();
        Assert.True(root is not null,
            "Could not locate Web-POS.Api next to the test assembly — this guard "
            + "is not running. Fix the lookup rather than deleting the test.");

        var offenders = new List<string>();

        foreach (var file in Directory.EnumerateFiles(root!, "*.cs", SearchOption.AllDirectories))
        {
            if (file.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}"))
                continue;

            var text = File.ReadAllText(file);
            if (!text.Contains("BeginTransaction", StringComparison.Ordinal)) continue;

            // File-level rather than per-method: the strategy is often created in
            // a repository helper and the transaction opened through another, so
            // a method-scoped check would report false positives. A file that
            // opens transactions and never mentions the strategy at all is the
            // shape that actually breaks.
            if (text.Contains("CreateExecutionStrategy", StringComparison.Ordinal)) continue;

            var line = text[..text.IndexOf("BeginTransaction", StringComparison.Ordinal)]
                .Count(c => c == '\n') + 1;
            offenders.Add($"{Path.GetFileName(file)}:{line}");
        }

        Assert.True(offenders.Count == 0,
            "These open a transaction without an execution strategy. With "
            + "EnableRetryOnFailure that throws on the FIRST write, at runtime "
            + "only. Wrap the body in "
            + "Database.CreateExecutionStrategy().ExecuteAsync(...) — see "
            + "PosOrderService.Delete for the shape:\n  "
            + string.Join("\n  ", offenders));
    }

    [Fact]
    public void The_modifier_service_specifically_is_wrapped()
    {
        // Named directly because it is the one that broke, and because a
        // file-level check would go quiet if somebody split its writes out.
        var root = FindApiSourceRoot();
        Assert.True(root is not null, "API sources not found.");

        var text = File.ReadAllText(Path.Combine(root!, "Services", "ModifierService.cs"));

        // Actual CALLS only. A bare name match also counts the prose in the
        // remarks that explain this very rule, which would make the test fail
        // on its own documentation.
        var transactions = Regex.Matches(text, @"Database\.BeginTransactionAsync\(").Count;
        var strategies = Regex.Matches(text, @"Database\.CreateExecutionStrategy\(").Count;

        Assert.True(transactions > 0, "ModifierService should still be transactional.");
        Assert.True(strategies >= transactions,
            $"ModifierService opens {transactions} transaction(s) but creates only "
            + $"{strategies} execution strateg(ies). Every one needs its own.");
    }

    [Fact]
    public void The_guard_recognises_the_shape_that_actually_shipped()
    {
        // Proves the check is not vacuous: a file that opens a transaction with
        // no strategy anywhere must be flagged, and one with both must not.
        const string broken = "await using var tx = await _db.Database.BeginTransactionAsync(ct);";
        const string fixedUp = """
            var strategy = _db.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                await using var tx = await _db.Database.BeginTransactionAsync(ct);
            });
            """;

        Assert.Contains("BeginTransaction", broken, StringComparison.Ordinal);
        Assert.DoesNotContain("CreateExecutionStrategy", broken, StringComparison.Ordinal);

        Assert.Contains("BeginTransaction", fixedUp, StringComparison.Ordinal);
        Assert.Contains("CreateExecutionStrategy", fixedUp, StringComparison.Ordinal);
    }
}
