using System.Diagnostics;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;

namespace Api.Startup;

/// <summary>
/// The banner printed once the server is listening: where to click, and whether
/// anything is wrong. Everything else that used to be dumped here now lives
/// behind <see cref="StartupDiagnostics"/>.
///
/// It runs on <c>ApplicationStarted</c> because the bound URLs do not exist until
/// then — asking Kestrel earlier returns nothing, which is why the old
/// browser-open code had to guess at <c>localhost:5002</c>.
///
/// Written with <c>Console</c> rather than <c>ILogger</c> on purpose: a banner
/// prefixed with <c>info: Program[0]</c> on every line is not a banner.
/// </summary>
public static class StartupConsole
{
    private const int Width = 64;

    /// <summary>
    /// Colour is skipped when output is redirected — on a server this stream is a
    /// log file, and escape codes there are just corruption.
    /// </summary>
    private static readonly bool UseColour = !Console.IsOutputRedirected;

    /// <summary>
    /// Pure ASCII. The Windows console's active code page is not guaranteed to
    /// carry box-drawing glyphs, and a banner that renders as "?????" on the one
    /// machine that matters is worse than a plain one.
    /// </summary>
    private static readonly string Rule = new('=', Width);

    public static void Register(WebApplication app, StartupReport report)
    {
        app.Lifetime.ApplicationStarted.Register(() =>
        {
            try
            {
                var urls = ResolveUrls(app);
                Print(app, report, urls);

                // Development convenience only: on a server there is no desktop to
                // open a browser on, and inside a test host it is pure noise.
                if (app.Environment.IsDevelopment())
                    OpenPortal(urls.Primary);
            }
            catch
            {
                // A cosmetic banner must never be able to take the API down.
            }
        });
    }

    private static void Print(WebApplication app, StartupReport report, ResolvedUrls urls)
    {
        Console.WriteLine();
        Line(Rule, ConsoleColor.DarkGray);
        Write("  WEB POS API", ConsoleColor.Cyan);
        Line($"   {app.Environment.EnvironmentName}", ConsoleColor.DarkGray);
        Line(Rule, ConsoleColor.DarkGray);
        Console.WriteLine();

        Link("Admin portal", $"{urls.Primary}/admin");
        Link("Swagger", $"{urls.Primary}/swagger");
        Link("API base", $"{urls.Primary}/api");

        foreach (var extra in urls.Others)
            Link("Also on", extra, ConsoleColor.DarkGray);

        Console.WriteLine();

        Status("POS database", report.AppDatabaseConnected, "connected", "UNREACHABLE");
        Status("Control plane", report.MasterDatabaseConnected, "connected", "UNREACHABLE");

        // "Admin accounts", not "Admin portal" — the label above already reads
        // "Admin portal" for the URL, and two rows with the same name saying
        // different things is how a status line gets misread.
        if (report.MasterDatabaseConnected)
            Status("Admin accounts", report.AdminPortalReady, "ready", "NOT USABLE - see the error above");

        if (report.AdminPortalOnDefaultPassword)
        {
            Console.WriteLine();
            Line("  !  An admin account still uses the default password.", ConsoleColor.Yellow);
            Line($"     Change it at {urls.Primary}/admin/account/password", ConsoleColor.Yellow);
        }

        if (report.HasProblems)
        {
            Console.WriteLine();
            Line($"     Set {StartupDiagnostics.ConfigKey}=true for the full configuration dump.",
                ConsoleColor.DarkGray);
        }

        Console.WriteLine();
        Line(Rule, ConsoleColor.DarkGray);
        Console.WriteLine();
    }

    // ── rendering helpers ────────────────────────────────────────────────────

    private static void Link(string label, string url, ConsoleColor colour = ConsoleColor.Cyan)
    {
        Write($"  {label.PadRight(15)}", ConsoleColor.Gray);
        Line(url, colour);
    }

    private static void Status(string label, bool ok, string okText, string badText)
    {
        Write($"  {label.PadRight(15)}", ConsoleColor.Gray);
        Line(ok ? okText : badText, ok ? ConsoleColor.Green : ConsoleColor.Red);
    }

    private static void Write(string text, ConsoleColor colour)
    {
        if (!UseColour) { Console.Write(text); return; }
        Console.ForegroundColor = colour;
        Console.Write(text);
        Console.ResetColor();
    }

    private static void Line(string text, ConsoleColor colour)
    {
        Write(text, colour);
        Console.WriteLine();
    }

    // ── URL resolution ───────────────────────────────────────────────────────

    private sealed record ResolvedUrls(string Primary, IReadOnlyList<string> Others);

    /// <summary>
    /// Prefers an http:// address as the primary because that is the one a browser
    /// opens without a certificate interstitial on the dev box. Any others are
    /// still listed — a terminal pointed at the wrong scheme is a real diagnosis.
    /// </summary>
    private static ResolvedUrls ResolveUrls(WebApplication app)
    {
        var addresses = app.Services.GetService<IServer>()?
            .Features.Get<IServerAddressesFeature>()?.Addresses;

        var normalised = (addresses ?? Array.Empty<string>())
            .Select(Normalise)
            .Where(a => !string.IsNullOrWhiteSpace(a))
            .Distinct()
            .ToList();

        if (normalised.Count == 0)
            return new ResolvedUrls("http://localhost:5002", Array.Empty<string>());

        var primary = normalised.FirstOrDefault(a => a.StartsWith("http://")) ?? normalised[0];
        return new ResolvedUrls(primary, normalised.Where(a => a != primary).ToList());
    }

    /// <summary>
    /// Wildcard binds are not addresses you can click. Kestrel reports what it was
    /// told to listen on, which may be 0.0.0.0 or [::].
    /// </summary>
    private static string Normalise(string address) => address
        .Replace("0.0.0.0", "localhost")
        .Replace("[::]", "localhost")
        .TrimEnd('/');

    private static void OpenPortal(string baseUrl)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = $"{baseUrl}/admin",
                UseShellExecute = true,
            });
        }
        catch { /* opening a browser is best-effort — never block startup */ }
    }
}
