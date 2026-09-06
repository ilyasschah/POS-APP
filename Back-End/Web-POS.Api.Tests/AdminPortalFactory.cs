using Api.DataBase;
using Api.Master;
using Api.Master.Domain;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Api.Tests;

/// <summary>
/// Boots the real <c>Program.cs</c> pipeline in-process.
///
/// Everything under test — the Razor Pages authorize/anonymous conventions, the
/// cookie scheme, the authorization policy that must name it, the security-header
/// middleware and its position relative to UseAuthorization — is wiring, and
/// wiring cannot be tested by re-declaring it. So the app is booted as it ships
/// and only the DATABASES are swapped for SQLite: they are not what is under test,
/// and they are the one dependency a machine may not have. On a developer box the
/// MSSQLSERVER service starts Manual, so it is simply not running after a reboot —
/// against SQL Server these tests then spend 33s inside EnableRetryOnFailure and
/// report a portal bug that does not exist.
///
/// 🚨 BOTH contexts, not just the Master one. The portal's own pages read the TENANT
/// database — /admin/companies lists companies through CompanyRepository, which is
/// AppDbContext — so a factory that swaps only MasterDbContext signs in happily and
/// then 500s on the first page behind the login.
/// </summary>
public class AdminPortalFactory : WebApplicationFactory<Program>
{
    public const string AdminUsername = "Admin";
    public const string AdminPassword = "portal-test-password";

    private readonly SqliteConnection _master = new("DataSource=:memory:");
    private readonly SqliteConnection _tenant = new("DataSource=:memory:");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Not "Development": that path downgrades every configuration error to a
        // warning, so a test host would keep booting after a real misconfiguration.
        // Deliberately NOT "Test" either — that is the OVH test server's own
        // environment name, and two different things answering to one name is how
        // someone later assumes this host reproduces that deployment.
        builder.UseEnvironment("IntegrationTest");

        // StartupConfigurationValidator is fatal outside Development, and it runs in
        // Program.cs's top-level statements — before any IWebHostBuilder callback can
        // contribute configuration. Environment variables are read by the
        // WebApplicationBuilder itself, so they are the only hook early enough.
        // Set only when the machine has none, so a real dev box keeps its own value.
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("Jwt__Secret")))
        {
            Environment.SetEnvironmentVariable(
                "Jwt__Secret", "test-only-signing-secret-that-is-long-enough-0123456789");
        }

        // Held open for the lifetime of the factory: an in-memory SQLite database
        // exists exactly as long as a connection to it does.
        _master.Open();
        _tenant.Open();

        // The tenant schema has to exist BEFORE the host boots. DatabaseBootstrapper
        // runs inside Program.cs's top-level statements and seeds global reference
        // data on the way up; against an empty database every one of those seeders
        // fails — harmlessly, since the bootstrapper is non-fatal, but noisily.
        //
        // Master is deliberately NOT created here. Tests seed it themselves through
        // SeedAdminAsync, and one of them asserts on the unseeded case.
        using (var tenant = new AppDbContext(
                   new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_tenant).Options))
        {
            tenant.Database.EnsureCreated();
        }

        builder.ConfigureTestServices(services =>
        {
            // ⚠️ A second AddDbContext does NOT replace the first. Since EF Core 9
            // the options lambda is registered as IDbContextOptionsConfiguration<T>
            // and EVERY registration is applied to the same options object, so
            // adding UseSqlite leaves UseSqlServer in place and the context dies
            // with "Only a single database provider can be registered".
            // Both descriptors have to go first.
            //
            // Each context is matched by its own generic argument, so swapping one
            // never disturbs the other.
            foreach (var descriptor in services.Where(IsOptionsFor<MasterDbContext>).ToList())
                services.Remove(descriptor);
            foreach (var descriptor in services.Where(IsOptionsFor<AppDbContext>).ToList())
                services.Remove(descriptor);

            services.AddDbContext<MasterDbContext>(opt => opt.UseSqlite(_master));
            services.AddDbContext<AppDbContext>(opt => opt.UseSqlite(_tenant));
        });
    }

    /// <summary>
    /// Every options registration EF holds for <typeparamref name="TContext"/> —
    /// both the built <c>DbContextOptions&lt;TContext&gt;</c> and the
    /// <c>IDbContextOptionsConfiguration&lt;TContext&gt;</c> callback that
    /// carries UseSqlServer. Matched by shape rather than by naming the interface,
    /// which is not in a namespace this project imports and has moved between EF
    /// versions. Anything belonging to the other context is left alone.
    /// </summary>
    private static bool IsOptionsFor<TContext>(ServiceDescriptor descriptor)
        where TContext : DbContext
    {
        var type = descriptor.ServiceType;
        if (!type.IsGenericType) return false;
        if (!type.GetGenericArguments().Contains(typeof(TContext))) return false;
        return type.Name.StartsWith("DbContextOptions") ||
               type.Name.StartsWith("IDbContextOptionsConfiguration");
    }

    /// <summary>
    /// Creates the master schema and one known admin account.
    ///
    /// Runs after the host is built, so it lands after Program.cs's own startup
    /// block — which fails harmlessly here, because its idempotent CREATE TABLE is
    /// T-SQL and this database is SQLite. That block's real DDL is verified
    /// against the live master database instead.
    /// </summary>
    public async Task SeedAdminAsync()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MasterDbContext>();
        await db.Database.EnsureCreatedAsync();

        if (await db.AdminUsers.AnyAsync()) return;

        db.AdminUsers.Add(new AdminUser
        {
            Username = AdminUsername,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(AdminPassword),
            DisplayName = "Administrator",
            IsActive = true,
        });
        await db.SaveChangesAsync();
    }

    /// <summary>
    /// Flips the seeded account's default-password flag, so the banner it drives
    /// can be tested without depending on the real startup seeder having run.
    /// </summary>
    public async Task SetMustChangePasswordAsync(bool value)
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MasterDbContext>();
        var user = await db.AdminUsers.SingleAsync(u => u.Username == AdminUsername);
        user.MustChangePassword = value;
        await db.SaveChangesAsync();
    }

    public HttpClient CreatePortalClient() =>
        CreateClient(new WebApplicationFactoryClientOptions
        {
            // Assert on the redirect itself. Following it would turn "challenged to
            // log in" and "served the page" into the same 200.
            AllowAutoRedirect = false,
        });

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (!disposing) return;
        _master.Dispose();
        _tenant.Dispose();
    }
}
