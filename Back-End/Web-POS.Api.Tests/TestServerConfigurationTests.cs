using Api.Admin;
using Api.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The OVH test box runs with <c>ASPNETCORE_ENVIRONMENT=Test</c>, where
/// StartupConfigurationValidator findings are FATAL — outside Development it
/// throws and the site never starts. A deploy that aborts here shows up as a
/// dead site, not as a message, so the exact configuration the workflow injects
/// is pinned rather than assumed.
///
/// Mirrors .github/workflows/deploy-backend-test.yml. If that file's injected
/// variables change, these tests must change with it.
/// </summary>
public class TestServerConfigurationTests : IDisposable
{
    private readonly string _contentRoot =
        Directory.CreateTempSubdirectory("pos-api-config-test").FullName;

    public void Dispose() => Directory.Delete(_contentRoot, recursive: true);

    private sealed class StubEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Test";
        public string ApplicationName { get; set; } = "Web-POS.Api";
        public string ContentRootPath { get; set; } = "";
        public IFileProvider ContentRootFileProvider { get; set; } = null!;
    }

    /// <summary>Exactly the variables the deploy workflow writes into web.config.</summary>
    private static IConfiguration DeployedConfiguration(
        string? jwtSecret = "a-real-looking-test-server-secret-of-sufficient-length",
        string? defaultConnection = "Data Source=localhost;Initial Catalog=web-pos;User ID=x;Password=y",
        string? masterConnection = "Data Source=localhost;Initial Catalog=web-pos-master;User ID=x;Password=y",
        string? seedPassword = "a-password-set-by-the-deployment") =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                // Keys as the app sees them: the workflow writes Jwt__Secret into
                // web.config and the environment-variable provider maps the double
                // underscore to the ':' separator before anything reads it.
                ["Jwt:Secret"] = jwtSecret,
                ["ConnectionStrings:DefaultConnection"] = defaultConnection,
                ["ConnectionStrings:MasterConnection"] = masterConnection,
                [AdminUserSeeder.SeedPasswordConfigKey] = seedPassword,
            })
            .Build();

    private StartupConfigurationValidator.ValidationReport Validate(
        IConfiguration config, string environmentName = "Test") =>
        StartupConfigurationValidator.Validate(
            config,
            new StubEnvironment { EnvironmentName = environmentName, ContentRootPath = _contentRoot });

    [Fact]
    public void The_test_servers_injected_configuration_starts_the_app()
    {
        var report = Validate(DeployedConfiguration());

        // Any error here means the OVH deploy comes back with a dead site.
        Assert.False(report.HasErrors);
    }

    [Fact]
    public void Dropping_the_retired_admin_portal_key_breaks_nothing()
    {
        // The workflow no longer injects AdminPortal__AccessKey. Nothing may complain
        // about its absence — least of all fatally.
        var report = Validate(DeployedConfiguration());

        Assert.DoesNotContain(report.Errors, e => e.Contains("AdminPortal", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(report.Warnings, w => w.Contains("AccessKey", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void A_missing_jwt_secret_is_still_fatal_outside_development()
    {
        // Proves the pass above is not vacuous: the validator really is armed in the
        // Test environment, so its silence there is a result and not an absence.
        var report = Validate(DeployedConfiguration(jwtSecret: null));

        Assert.True(report.HasErrors);
        Assert.Contains(report.Errors, e => e.Contains("Jwt:Secret"));
    }

    [Fact]
    public void A_missing_master_connection_string_does_not_abort_startup()
    {
        // Admin accounts live in the Master DB, so it is tempting to make it required.
        // It must stay a warning: the POS API's own endpoints work without the control
        // plane, and taking every till offline because a back-office database is
        // unreachable would be a far worse failure than /admin being unusable.
        var report = Validate(DeployedConfiguration(masterConnection: null));

        Assert.False(report.HasErrors);
        Assert.Contains(report.Warnings, w => w.Contains("MasterConnection"));
    }

    [Fact]
    public void Development_still_boots_with_nothing_configured_at_all()
    {
        // The dev box relies on this: a fresh clone with no environment set up must
        // still run. Pinned because the Test-environment work above is exactly the
        // kind of change that would quietly make local startup fatal too.
        var report = Validate(
            DeployedConfiguration(jwtSecret: null, defaultConnection: null, masterConnection: null),
            environmentName: "Development");

        Assert.False(report.HasErrors);
    }
}
