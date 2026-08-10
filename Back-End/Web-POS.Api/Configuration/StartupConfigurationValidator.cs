using System.Security.Cryptography;
using System.Text;

namespace Api.Configuration;

/// <summary>
/// Validates every setting the API needs *before* anything is wired up, so a
/// misconfigured deployment fails at startup with an actionable message instead
/// of at 2am on the first login.
///
/// Policy: outside Development, anything in <see cref="ValidationReport.Errors"/>
/// aborts startup. In Development the same findings are downgraded to warnings so
/// a fresh clone still runs with zero setup.
/// </summary>
public static class StartupConfigurationValidator
{
    public sealed class ValidationReport
    {
        public List<string> Errors { get; } = new();
        public List<string> Warnings { get; } = new();
        public bool HasErrors => Errors.Count > 0;
    }

    public static ValidationReport Validate(IConfiguration config, IHostEnvironment env)
    {
        var report = new ValidationReport();
        var isDev = env.IsDevelopment();

        ValidateJwtSecret(config, report);
        // There is deliberately no AdminPortal:AccessKey check any more. The portal
        // moved to per-user accounts in the Master DB (Api.Admin.AdminUserSeeder),
        // so there is no shared secret left to configure or to get wrong.
        ValidateLeaseSigningKey(config, env, report);
        ValidateConnectionStrings(config, report);

        // In Development every finding is advisory — collapse errors into warnings
        // so `git clone && dotnet run` works with no environment set up at all.
        if (isDev && report.HasErrors)
        {
            foreach (var error in report.Errors)
                report.Warnings.Add($"[would be FATAL outside Development] {error}");
            report.Errors.Clear();
        }

        return report;
    }

    private static void ValidateJwtSecret(IConfiguration config, ValidationReport report)
    {
        var secret = config["Jwt:Secret"];

        if (string.IsNullOrWhiteSpace(secret))
        {
            report.Errors.Add(
                "Jwt:Secret is not set. Tokens cannot be signed.\n" +
                "    Fix: set the environment variable  Jwt__Secret  (DOUBLE underscore) to a\n" +
                "         random string of at least 32 characters, then restart.\n" +
                "         PowerShell:  [Environment]::SetEnvironmentVariable(\"Jwt__Secret\", \"<value>\", \"Machine\")\n" +
                "         Generate one: [Convert]::ToHexString((1..48 | %{ Get-Random -Max 256 }))");
            return;
        }

        if (secret.Length < JwtSettings.MinimumSecretLength)
        {
            report.Errors.Add(
                $"Jwt:Secret is only {secret.Length} characters; HMAC-SHA256 signing requires at " +
                $"least {JwtSettings.MinimumSecretLength}.\n" +
                "    Fix: replace Jwt__Secret with a longer random value and restart.");
            return;
        }

        if (JwtSettings.KnownPlaceholders.Contains(secret))
        {
            report.Errors.Add(
                "Jwt:Secret is still a placeholder value shipped with the source. Anyone with the\n" +
                "    repository can forge Admin tokens.\n" +
                "    Fix: replace Jwt__Secret with a real random secret and restart.");
        }
    }

    private static void ValidateLeaseSigningKey(
        IConfiguration config, IHostEnvironment env, ValidationReport report)
    {
        var pem = config["Lease:PrivateKeyPem"];
        var keyPath = Path.Combine(env.ContentRootPath, "lease_signing_key.pem");

        if (!string.IsNullOrWhiteSpace(pem))
        {
            // Parse it now. Previously a malformed PEM surfaced as an exception deep
            // inside DI resolution on the first login request, not at startup.
            try
            {
                using var rsa = RSA.Create();
                rsa.ImportFromPem(pem);
                if (rsa.KeySize < 2048)
                {
                    report.Warnings.Add(
                        $"Lease:PrivateKeyPem is only a {rsa.KeySize}-bit RSA key; 2048-bit minimum " +
                        "is recommended for lease signing.");
                }
            }
            catch (Exception ex)
            {
                report.Errors.Add(
                    $"Lease:PrivateKeyPem is set but could not be parsed as an RSA private key: {ex.Message}\n" +
                    "    Fix: supply a valid PEM (-----BEGIN RSA PRIVATE KEY----- ... -----END ...-----).\n" +
                    "         Multi-line PEMs do not survive `setx` — use a secret store, appsettings\n" +
                    "         override, or web.config <environmentVariables> instead.");
            }
            return;
        }

        if (File.Exists(keyPath))
        {
            try
            {
                using var rsa = RSA.Create();
                rsa.ImportFromPem(File.ReadAllText(keyPath));
            }
            catch (Exception ex)
            {
                report.Errors.Add(
                    $"The lease signing key at {keyPath} is corrupt and cannot be parsed: {ex.Message}\n" +
                    "    Fix: restore the original key file, or delete it to have a new keypair\n" +
                    "         generated (NOTE: this invalidates every lease already issued).");
            }
            return;
        }

        // No key anywhere — LeaseKeyService will generate one. Verify it can actually
        // write first; under IIS the app-pool identity often cannot, and that failure
        // would otherwise surface as a 500 on the first login rather than at startup.
        var canWrite = CanWriteToDirectory(env.ContentRootPath, out var writeError);
        if (!canWrite)
        {
            report.Errors.Add(
                $"No lease signing key is configured, none exists at {keyPath}, and the content root " +
                $"is not writable so one cannot be generated: {writeError}\n" +
                "    Fix: either grant the application identity write access to the content root,\n" +
                "         copy an existing lease_signing_key.pem there, or set Lease:PrivateKeyPem.");
        }
        else
        {
            report.Warnings.Add(
                $"No lease signing key found — a NEW keypair will be generated at {keyPath}.\n" +
                "    Every offline lease previously issued by another instance will fail validation\n" +
                "    against it. If this server is replacing an existing one, copy the original\n" +
                "    lease_signing_key.pem across before letting clients connect.");
        }
    }

    private static void ValidateConnectionStrings(IConfiguration config, ValidationReport report)
    {
        var defaultCs = config.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(defaultCs))
        {
            report.Errors.Add(
                "ConnectionStrings:DefaultConnection is not set — the API cannot reach the POS database.\n" +
                "    Fix: set the environment variable  ConnectionStrings__DefaultConnection\n" +
                "         (DOUBLE underscores between ConnectionStrings and the name).");
        }

        // Optional by design — Program.cs falls back to DefaultConnection.
        if (string.IsNullOrWhiteSpace(config.GetConnectionString("MasterConnection")))
        {
            report.Warnings.Add(
                "ConnectionStrings:MasterConnection is not set; the SaaS control-plane context will " +
                "share the POS database. Set ConnectionStrings__MasterConnection to split them.");
        }
    }

    private static bool CanWriteToDirectory(string path, out string error)
    {
        error = string.Empty;
        try
        {
            var probe = Path.Combine(path, $".writeprobe-{Guid.NewGuid():N}.tmp");
            File.WriteAllText(probe, string.Empty);
            File.Delete(probe);
            return true;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            return false;
        }
    }

    /// <summary>
    /// Renders the report's errors into one exception message. Every problem is
    /// listed at once so a fresh deployment can be fixed in a single pass rather
    /// than discovering the next missing setting on each restart.
    /// </summary>
    public static string FormatFatalMessage(ValidationReport report, IHostEnvironment env)
    {
        var sb = new StringBuilder();
        sb.AppendLine();
        sb.AppendLine("================================================================");
        sb.AppendLine($" STARTUP ABORTED — invalid configuration ({env.EnvironmentName})");
        sb.AppendLine("================================================================");
        for (var i = 0; i < report.Errors.Count; i++)
        {
            sb.AppendLine($"  {i + 1}. {report.Errors[i]}");
            sb.AppendLine();
        }
        sb.AppendLine("  Environment variables use DOUBLE underscores to express nesting:");
        sb.AppendLine("      Jwt:Secret            ->  Jwt__Secret");
        sb.AppendLine("  A shell opened before the variable was set will not see it — open a new one.");
        sb.AppendLine("================================================================");
        return sb.ToString();
    }
}
