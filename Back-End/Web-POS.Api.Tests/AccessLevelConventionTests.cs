using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using Api.Domain;
using Xunit;

namespace Api.Tests;

/// <summary>
/// `AccessLevel` means the same thing everywhere: **0 is Admin.**
/// </summary>
/// <remarks>
/// 🚨 This shipped, and it shipped as three forms in ONE portal disagreeing.
/// `Users/Edit` offered `0 = Admin`; `Companies/Create` and `Companies/Details`
/// offered `1 = Admin`. So provisioning a company and picking "Admin" for its
/// first user created a CASHIER — one who could not open Management, on a
/// company with no administrator at all — and the user list on the same page
/// rendered its badge with the same inversion, so the portal confirmed the lie
/// back to you. The only surface telling the truth was the till, at the moment
/// somebody was refused.
///
/// Nothing could catch it: both numbers are valid `int`s, every layer compiled,
/// the API stored exactly what it was sent, and the round-trip through the
/// portal was self-consistent. The only witness was a real login.
///
/// So the guard is: no view may write the numbers itself. They come from
/// <see cref="AccessLevels.Options"/>, which is the one place the mapping is
/// stated.
/// </remarks>
public class AccessLevelConventionTests
{
    [Fact]
    public void Zero_is_admin_and_one_is_cashier()
    {
        // The rest of the system is built on this: SecurityGuard.canAccess
        // short-circuits on 0, the POS user list prints 0 as Admin, and the
        // owner dashboard's isAdmin is `accessLevel == 0`. If this assertion is
        // ever "fixed" to match a form, every one of those flips meaning.
        Assert.Equal(0, AccessLevels.Admin);
        Assert.Equal(1, AccessLevels.Cashier);
        Assert.Equal("Admin", AccessLevels.Name(0));
        Assert.Equal("Cashier", AccessLevels.Name(1));
    }

    [Fact]
    public void An_unrecognised_level_reads_as_the_restricted_one()
    {
        // Fail-restrictive, and it matches what the guard actually does with a
        // level it does not know: anything that is not 0 is subject to rules.
        Assert.Equal("Cashier", AccessLevels.Name(7));
        Assert.Equal("Cashier", AccessLevels.Name(-1));
    }

    [Fact]
    public void No_razor_page_hardcodes_the_role_numbers()
    {
        var pages = Path.Combine(ApiRoot(), "Pages");
        Assert.True(Directory.Exists(pages), "Pages folder not found — this guard is not running.");

        // An <option> that pairs a literal 0/1 with the word Admin or Cashier.
        // That is the exact shape that shipped inverted, in two files.
        var hardcoded = new Regex(
            @"<option\s+value\s*=\s*""[01]""\s*>\s*(Admin|Cashier)",
            RegexOptions.IgnoreCase);

        var offenders = new List<string>();
        foreach (var file in Directory.EnumerateFiles(pages, "*.cshtml", SearchOption.AllDirectories))
        {
            foreach (Match m in hardcoded.Matches(File.ReadAllText(file)))
            {
                offenders.Add($"{Path.GetFileName(file)}: {m.Value.Trim()}");
            }
        }

        Assert.True(offenders.Count == 0,
            "A role dropdown writes the access-level numbers itself. Bind it to "
            + "Api.Domain.AccessLevels.Options instead — that is the only place "
            + "the mapping is stated, and hand-written options are how the "
            + "portal ended up offering two different ones:\n  "
            + string.Join("\n  ", offenders));
    }

    private static string ApiRoot([CallerFilePath] string thisFile = "")
    {
        var beside = Path.GetDirectoryName(Path.GetDirectoryName(thisFile));
        return Path.Combine(beside!, "Web-POS.Api");
    }
}
