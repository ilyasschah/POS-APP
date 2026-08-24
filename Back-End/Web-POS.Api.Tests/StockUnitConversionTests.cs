using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using Api.Domain;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Every place the server adds to or subtracts from a Stock row.
///
/// The rule is one line long and has now been broken twice, on both sides of
/// the wire: <b>a document or order line is counted in the product's SALE unit,
/// a Stock row is held in its category's REFERENCE unit, and the two may never
/// meet without <see cref="UnitOfMeasure.ToReference"/> between them.</b>
/// Refunding 100 g of a gram-priced product returns 0.100 kg; adding the raw
/// 100 returns a hundred kilograms of saffron that never existed.
///
/// What made this expensive to find is that it survived a correct client. The
/// till converted properly and wrote 0.500 into its own cache, the server added
/// 100 to the same row, and the next <c>pullStocks</c> overwrote the good local
/// figure with the server's. The screen was wrong, the client was right, and
/// nothing in the client could be changed to fix it.
///
/// So these come in two halves: the arithmetic each handler performs, and a
/// scan of the API sources proving no handler ANYWHERE does the arithmetic
/// without the conversion. The second half is the one that catches the next
/// site somebody adds.
/// </summary>
public class StockUnitConversionTests
{
    private const int Kg = 10;
    private const int G = 11;
    private const int Pieces = 1;

    // ── The reported case, arm by arm ────────────────────────────────────────

    [Fact]
    public void Voiding_a_gram_sale_returns_grams_worth_of_stock()
    {
        // Saffron: unit g, 30.00/g, half a kilo on the shelf. Selling 100 g
        // took it to 0.400; the void must land back on exactly 0.500.
        var stock = 0.400m;

        stock += UnitOfMeasure.ToReference(100m, G);

        Assert.Equal(0.500m, stock);
    }

    [Fact]
    public void Refunding_a_gram_sale_returns_grams_worth_of_stock()
    {
        var stock = 0.400m;

        stock += UnitOfMeasure.ToReference(100m, G);

        Assert.Equal(0.500m, stock);
        Assert.True(stock < 1m, "a hundred kilograms of saffron is the bug");
    }

    [Fact]
    public void A_sale_and_its_reversal_cancel_exactly()
    {
        // Any asymmetry here leaks stock a fraction at a time, which is worse
        // than an obvious error because nobody notices for months.
        var stock = 0.500m;

        stock -= UnitOfMeasure.ToReference(137m, G);
        stock += UnitOfMeasure.ToReference(137m, G);

        Assert.Equal(0.500m, stock);
    }

    [Fact]
    public void A_kilogram_product_is_completely_unaffected()
    {
        // The conversion is the identity for a product sold in its own
        // reference unit — which is why adding it cannot disturb existing data.
        var stock = 257.500m;

        stock += UnitOfMeasure.ToReference(0.500m, Kg);

        Assert.Equal(258.000m, stock);
    }

    [Fact]
    public void A_pieces_product_is_completely_unaffected_fractions_included()
    {
        var stock = 88.0m;

        stock += UnitOfMeasure.ToReference(0.5m, Pieces);

        Assert.Equal(88.5m, stock);
    }

    // ── The guard that catches the NEXT one ──────────────────────────────────

    /// <summary>
    /// Locates the API sources, which sit beside this test project.
    ///
    /// Anchored on THIS FILE's own compile-time path rather than on
    /// <see cref="AppContext.BaseDirectory"/>, because the build output is not
    /// reliably inside the repo: the documented way to build while the API is
    /// running under a debugger redirects <c>BaseOutputPath</c> to a scratch
    /// directory, and walking up from there never reaches the solution at all.
    /// The assembly walk stays as the fallback for a run whose sources have
    /// moved since compilation.
    /// </summary>
    private static string? FindApiSourceRoot([CallerFilePath] string thisFile = "")
    {
        var beside = Path.GetDirectoryName(Path.GetDirectoryName(thisFile));
        if (beside is not null && IsApiRoot(Path.Combine(beside, "Web-POS.Api")))
            return Path.Combine(beside, "Web-POS.Api");

        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "Web-POS.Api");
            if (IsApiRoot(candidate)) return candidate;
            dir = dir.Parent;
        }
        return null;
    }

    private static bool IsApiRoot(string path) =>
        Directory.Exists(path) &&
        File.Exists(Path.Combine(path, "Domain", "UnitOfMeasure.cs"));

    [Fact]
    public void No_handler_adds_a_raw_line_quantity_to_a_stock_row()
    {
        var root = FindApiSourceRoot();
        // Loud, not skipped: a guard that quietly stops running is worse than
        // no guard, because the next unconverted site ships unnoticed.
        Assert.True(root is not null,
            "Could not locate Web-POS.Api next to the test assembly — this guard "
            + "is not running. Fix the lookup rather than deleting the test.");

        // Anything of the shape `stock.Quantity + <operand>`. A CONVERTED
        // operand is always either a local holding the converted figure
        // (`restored`, `deltaInStockUnit`) or the call itself; a RAW one is
        // always some line's own `.Quantity`, because that is the only place an
        // unconverted quantity comes from. So the rule is exactly: the operand
        // must not end in `.Quantity`.
        var arithmetic = new Regex(
            @"stock\.Quantity\s*[+\-]\s*(?<operand>[A-Za-z_][A-Za-z0-9_\.]*)",
            RegexOptions.Compiled);

        var offenders = new List<string>();

        foreach (var file in Directory.EnumerateFiles(root!, "*.cs", SearchOption.AllDirectories))
        {
            // Generated migration snapshots restate old model state and never
            // move stock.
            if (file.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}"))
                continue;

            var lines = File.ReadAllLines(file);
            for (var i = 0; i < lines.Length; i++)
            {
                foreach (Match m in arithmetic.Matches(lines[i]))
                {
                    var operand = m.Groups["operand"].Value;
                    if (!operand.EndsWith(".Quantity", StringComparison.Ordinal)) continue;

                    offenders.Add(
                        $"{Path.GetFileName(file)}:{i + 1} → stock.Quantity ± {operand}");
                }
            }
        }

        Assert.True(
            offenders.Count == 0,
            "A stock row was moved by a raw line quantity. Wrap it in "
            + "UnitOfMeasure.ToReference(qty, product.UomId) — see "
            + "PosOrderVoidService for the shape:\n  "
            + string.Join("\n  ", offenders));
    }

    [Fact]
    public void Every_stock_mutating_file_references_the_conversion()
    {
        // The companion check: a file that touches `stock.Quantity` arithmetic
        // must mention ToReference somewhere, so a future handler cannot slip a
        // pre-converted-looking local past the regex above without ever having
        // converted anything.
        var root = FindApiSourceRoot();
        // Loud, not skipped: a guard that quietly stops running is worse than
        // no guard, because the next unconverted site ships unnoticed.
        Assert.True(root is not null,
            "Could not locate Web-POS.Api next to the test assembly — this guard "
            + "is not running. Fix the lookup rather than deleting the test.");

        var missing = new List<string>();

        foreach (var file in Directory.EnumerateFiles(root!, "*.cs", SearchOption.AllDirectories))
        {
            if (file.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}"))
                continue;

            var text = File.ReadAllText(file);
            if (!Regex.IsMatch(text, @"stock\.Quantity\s*[+\-]")) continue;
            if (text.Contains("UnitOfMeasure.ToReference", StringComparison.Ordinal)) continue;

            missing.Add(Path.GetFileName(file));
        }

        Assert.True(
            missing.Count == 0,
            "These files move stock but never convert a unit:\n  "
            + string.Join("\n  ", missing));
    }

    [Fact]
    public void The_guard_would_actually_catch_the_bug_it_was_written_for()
    {
        // Proves the regex is not vacuous: the exact line that shipped in
        // ProcessRefundCommand must be recognised as an offender.
        var arithmetic = new Regex(
            @"stock\.Quantity\s*[+\-]\s*(?<operand>[A-Za-z_][A-Za-z0-9_\.]*)");

        var shipped = arithmetic.Match("stock.Quantity + ri.Quantity,");
        var fixedUp = arithmetic.Match("stock.Quantity + restored,");

        Assert.True(shipped.Success);
        Assert.EndsWith(".Quantity", shipped.Groups["operand"].Value);

        Assert.True(fixedUp.Success);
        Assert.DoesNotContain(".Quantity", fixedUp.Groups["operand"].Value);
    }
}
