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
/// and only the Master DB is swapped for SQLite, which is not what is under test
/// and is the one dependency a machine may not have.
/// </summary>
public class AdminPortalFactory : WebApplicationFactory<Program>
{
    public const string AdminUsername = "Admin";
    public const string AdminPassword = "portal-test-password";

    private readonly SqliteConnection _master = new("DataSource=:memory:");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Not "Development": that path downgrades every configuration error to a
        // warning, so a test host would keep booting after a real misconfiguration.
        builder.UseEnvironment("Testing");

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

        _master.Open();

        builder.ConfigureTestServices(services =>
        {
            // ⚠️ A second AddDbContext does NOT replace the first. Since EF Core 9
            // the options lambda is registered as IDbContextOptionsConfiguration<T>
            // and EVERY registration is applied to the same options object, so
            // adding UseSqlite leaves UseSqlServer in place and the context dies
            // with "Only a single database provider can be registered".
            // Both descriptors have to go first.
            //
            // Scoped to MasterDbContext by its generic argument: AppDbContext must
            // keep its SQL Server registration untouched.
            foreach (var descriptor in services.Where(IsMasterDbOptions).ToList())
                services.Remove(descriptor);

            services.AddDbContext<MasterDbContext>(opt => opt.UseSqlite(_master));
        });
    }

    /// <summary>
    /// Every options registration EF holds for <see cref="MasterDbContext"/> —
    /// both the built <c>DbContextOptions&lt;MasterDbContext&gt;</c> and the
    /// <c>IDbContextOptionsConfiguration&lt;MasterDbContext&gt;</c> callback that
    /// carries UseSqlServer. Matched by shape rather than by naming the interface,
    /// which is not in a namespace this project imports and has moved between EF
    /// versions. Anything belonging to AppDbContext is left alone.
    /// </summary>
    private static bool IsMasterDbOptions(ServiceDescriptor descriptor)
    {
        var type = descriptor.ServiceType;
        if (!type.IsGenericType) return false;
        if (!type.GetGenericArguments().Contains(typeof(MasterDbContext))) return false;
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
        if (disposing) _master.Dispose();
    }
}
