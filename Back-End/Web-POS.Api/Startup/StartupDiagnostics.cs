using Api.Configuration;

namespace Api.Startup;

/// <summary>
/// The full configuration dump — every resolved value, masked, with the provider
/// that actually supplied it.
///
/// It answers one question: <i>"is this machine really reading my environment
/// variables?"</i> That is not a hypothetical — a connection string silently
/// reverting to the wrong host has cost this project a session more than once,
/// and the "which provider won" column is what settles it.
///
/// ⚠️ It is OFF by default because it is a dozen lines nobody needs on a healthy
/// boot. Turn it on with <c>Startup:Diagnostics=true</c> (environment variable
/// <c>Startup__Diagnostics=true</c>) when something looks wrong. The startup
/// banner prints that hint automatically whenever it detects a problem.
/// </summary>
public static class StartupDiagnostics
{
    public const string ConfigKey = "Startup:Diagnostics";

    public static bool IsEnabled(IConfiguration config) =>
        config.GetValue(ConfigKey, false);

    /// <summary>
    /// Config warnings always print, whatever the flag says — they are findings,
    /// not diagnostics. In Development this also carries what WOULD have been
    /// fatal on a server, so problems surface on the dev box first.
    /// </summary>
    public static void WriteWarnings(
        ILogger logger, StartupConfigurationValidator.ValidationReport report)
    {
        foreach (var warning in report.Warnings)
            logger.LogWarning("CONFIG: {warning}", warning);
    }

    public static void WriteIfEnabled(WebApplication app, ILogger logger, string dataProtectionKeyStore)
    {
        if (!IsEnabled(app.Configuration)) return;

        var config = app.Configuration;

        logger.LogInformation("--- Configuration providers (later overrides earlier) ---");
        if (config is IConfigurationRoot configRoot)
        {
            foreach (var provider in configRoot.Providers)
                logger.LogInformation("    {provider}", provider.ToString());
        }

        logger.LogInformation("--- Resolved configuration ---");
        logger.LogInformation("Content root             : {value}", app.Environment.ContentRootPath);
        logger.LogInformation("ASPNETCORE_ENVIRONMENT   : {value}",
            Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
                ?? "<not set> -> defaults to Production");
        Report(logger, config, "Jwt:Secret", MaskSecret(config["Jwt:Secret"]));
        Report(logger, config, "Jwt:Issuer", config["Jwt:Issuer"] ?? "<not set>");
        Report(logger, config, "Jwt:Audience", config["Jwt:Audience"] ?? "<not set>");
        Report(logger, config, "Lease:PrivateKeyPem",
            string.IsNullOrWhiteSpace(config["Lease:PrivateKeyPem"])
                ? "<not set> -> falling back to lease_signing_key.pem on disk"
                : $"<supplied, {config["Lease:PrivateKeyPem"]!.Length} chars>");
        Report(logger, config, "ConnectionStrings:DefaultConnection",
            MaskConnectionString(config.GetConnectionString("DefaultConnection")));
        Report(logger, config, "ConnectionStrings:MasterConnection",
            MaskConnectionString(config.GetConnectionString("MasterConnection")));
        Report(logger, config, Api.Admin.AdminUserSeeder.SeedPasswordConfigKey,
            string.IsNullOrWhiteSpace(config[Api.Admin.AdminUserSeeder.SeedPasswordConfigKey])
                ? "<not set> -> first admin seeds with the PUBLISHED default password"
                : "<supplied>");

        // Not a configuration key, but the answer to "why did everyone get signed
        // out again", which is otherwise diagnosed by guesswork.
        logger.LogInformation("DataProtection keys      : {value}", dataProtectionKeyStore);
    }

    private static void Report(ILogger logger, IConfiguration config, string key, string value) =>
        logger.LogInformation("{key} : {value}  [source: {source}]", key.PadRight(24), value, SourceOf(config, key));

    /// <summary>First/last four characters only — never log a whole secret.</summary>
    private static string MaskSecret(string? value)
    {
        if (string.IsNullOrEmpty(value)) return "<EMPTY / NOT SET>";
        if (value.Length <= 8) return $"**** (len={value.Length} - suspiciously short)";
        return $"{value[..4]}...{value[^4..]} (len={value.Length})";
    }

    private static string MaskConnectionString(string? cs) =>
        string.IsNullOrEmpty(cs)
            ? "<EMPTY / NOT SET>"
            : System.Text.RegularExpressions.Regex.Replace(
                cs, @"(Password\s*=\s*)[^;]*", "$1****",
                System.Text.RegularExpressions.RegexOptions.IgnoreCase);

    /// <summary>
    /// Providers are applied in order and the LAST one holding a key wins, so walk
    /// them backwards and report the first hit — that is the effective source.
    /// </summary>
    private static string SourceOf(IConfiguration config, string key)
    {
        if (config is not IConfigurationRoot root) return "unknown";
        foreach (var provider in root.Providers.Reverse())
        {
            if (provider.TryGet(key, out _))
                return provider.ToString() ?? provider.GetType().Name;
        }
        return "<no provider supplied this key>";
    }
}
