using Api.Admin;
using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The seed runs on EVERY startup, so "it must never reset an account that
/// already exists" is not a nicety — getting it wrong silently restores
/// <c>Admin@123</c> on a portal whose password was changed months ago, and nothing
/// on screen would say so.
/// </summary>
public class AdminUserSeederTests
{
    private static Task<bool> SeedAsync(MasterDbFixture fx, string? configuredPassword = null)
    {
        using var db = fx.NewContext();
        return AdminUserSeeder.SeedFirstAdminAsync(db, NullLogger.Instance, configuredPassword);
    }

    [Fact]
    public async Task Seeds_the_default_admin_when_the_table_is_empty()
    {
        using var fx = new MasterDbFixture();

        Assert.True(await SeedAsync(fx));

        using var db = fx.NewContext();
        var user = await db.AdminUsers.SingleAsync();
        Assert.Equal(AdminUserSeeder.DefaultUsername, user.Username);
        Assert.True(user.IsActive);
        Assert.True(user.MustChangePassword);
        Assert.Null(user.LastLoginAt);
    }

    [Fact]
    public async Task Stores_a_bcrypt_hash_that_verifies_the_default_password()
    {
        using var fx = new MasterDbFixture();
        await SeedAsync(fx);

        using var db = fx.NewContext();
        var user = await db.AdminUsers.SingleAsync();

        // The stored value must not be the password, nor anything that contains it.
        Assert.DoesNotContain(AdminUserSeeder.DefaultPassword, user.PasswordHash);
        Assert.StartsWith("$2", user.PasswordHash);

        // Verified through BCrypt itself rather than compared to a constant: a test
        // asserting a hardcoded hash would pass against a hash of anything.
        Assert.True(BCrypt.Net.BCrypt.Verify(AdminUserSeeder.DefaultPassword, user.PasswordHash));
        Assert.False(BCrypt.Net.BCrypt.Verify("Admin@1234", user.PasswordHash));
        Assert.False(BCrypt.Net.BCrypt.Verify("", user.PasswordHash));
    }

    [Fact]
    public async Task A_configured_seed_password_replaces_the_published_default()
    {
        // How a public server avoids standing up /admin with a password anyone can
        // read in this repository.
        using var fx = new MasterDbFixture();
        const string deployed = "a-secret-set-by-the-deployment";

        Assert.True(await SeedAsync(fx, deployed));

        using var db = fx.NewContext();
        var user = await db.AdminUsers.SingleAsync();

        Assert.True(BCrypt.Net.BCrypt.Verify(deployed, user.PasswordHash));
        Assert.False(BCrypt.Net.BCrypt.Verify(AdminUserSeeder.DefaultPassword, user.PasswordHash));

        // No banner: the credential is already the operator's own, and a warning
        // they cannot clear only teaches them to ignore warnings.
        Assert.False(user.MustChangePassword);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task A_blank_configured_password_falls_back_to_the_default_and_warns(string? configured)
    {
        // The shape a mis-wired CI secret takes. Seeding an empty password would be
        // far worse than seeding the documented one.
        using var fx = new MasterDbFixture();

        Assert.True(await SeedAsync(fx, configured));

        using var db = fx.NewContext();
        var user = await db.AdminUsers.SingleAsync();

        Assert.True(BCrypt.Net.BCrypt.Verify(AdminUserSeeder.DefaultPassword, user.PasswordHash));
        Assert.False(BCrypt.Net.BCrypt.Verify("", user.PasswordHash));
        Assert.True(user.MustChangePassword);
    }

    [Fact]
    public async Task A_configured_password_never_overwrites_an_existing_account()
    {
        // The seed password is injected on EVERY deploy, so it must stay inert once
        // an account exists — otherwise each release would silently reset a password
        // the operator had changed, back to whatever is in the CI secret.
        using var fx = new MasterDbFixture();
        await SeedAsync(fx);

        Assert.False(await SeedAsync(fx, "a-different-password-from-a-later-deploy"));

        using var db = fx.NewContext();
        var user = await db.AdminUsers.SingleAsync();
        Assert.True(BCrypt.Net.BCrypt.Verify(AdminUserSeeder.DefaultPassword, user.PasswordHash));
        Assert.False(BCrypt.Net.BCrypt.Verify("a-different-password-from-a-later-deploy", user.PasswordHash));
    }

    [Fact]
    public async Task Every_seeded_hash_is_salted_differently()
    {
        using var a = new MasterDbFixture();
        using var b = new MasterDbFixture();
        await SeedAsync(a);
        await SeedAsync(b);

        using var dbA = a.NewContext();
        using var dbB = b.NewContext();

        // Same password, different hash — proves a per-account salt, so one
        // recovered hash says nothing about any other install.
        Assert.NotEqual(
            (await dbA.AdminUsers.SingleAsync()).PasswordHash,
            (await dbB.AdminUsers.SingleAsync()).PasswordHash);
    }

    [Fact]
    public async Task Running_it_again_creates_nothing_and_leaves_the_hash_alone()
    {
        using var fx = new MasterDbFixture();
        Assert.True(await SeedAsync(fx));

        string hashAfterFirstRun;
        using (var db = fx.NewContext())
            hashAfterFirstRun = (await db.AdminUsers.SingleAsync()).PasswordHash;

        Assert.False(await SeedAsync(fx));
        Assert.False(await SeedAsync(fx));

        using var after = fx.NewContext();
        Assert.Equal(1, await after.AdminUsers.CountAsync());
        Assert.Equal(hashAfterFirstRun, (await after.AdminUsers.SingleAsync()).PasswordHash);
    }

    [Fact]
    public async Task Never_resets_a_password_that_has_been_changed()
    {
        using var fx = new MasterDbFixture();
        await SeedAsync(fx);

        const string chosen = "correct-horse-battery-staple";
        using (var db = fx.NewContext())
        {
            var user = await db.AdminUsers.SingleAsync();
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(chosen);
            user.MustChangePassword = false;
            await db.SaveChangesAsync();
        }

        Assert.False(await SeedAsync(fx));

        using var after = fx.NewContext();
        var reloaded = await after.AdminUsers.SingleAsync();
        Assert.True(BCrypt.Net.BCrypt.Verify(chosen, reloaded.PasswordHash));
        Assert.False(BCrypt.Net.BCrypt.Verify(AdminUserSeeder.DefaultPassword, reloaded.PasswordHash));
        Assert.False(reloaded.MustChangePassword);
    }

    [Fact]
    public async Task Stays_inert_when_the_seeded_account_was_renamed_or_replaced()
    {
        using var fx = new MasterDbFixture();

        // No account called "Admin" anywhere — but the portal HAS an operator, so
        // recreating the default would hand out a known credential on a live system.
        using (var db = fx.NewContext())
        {
            db.AdminUsers.Add(new AdminUser
            {
                Username = "ilyass",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("something-else"),
                IsActive = true,
            });
            await db.SaveChangesAsync();
        }

        Assert.False(await SeedAsync(fx));

        using var after = fx.NewContext();
        Assert.Equal(1, await after.AdminUsers.CountAsync());
        Assert.False(await after.AdminUsers.AnyAsync(u => u.Username == AdminUserSeeder.DefaultUsername));
    }

    [Fact]
    public async Task Stays_inert_when_the_only_account_is_disabled()
    {
        using var fx = new MasterDbFixture();
        await SeedAsync(fx);

        using (var db = fx.NewContext())
        {
            var user = await db.AdminUsers.SingleAsync();
            user.IsActive = false;
            await db.SaveChangesAsync();
        }

        // Deliberate: a disabled account was disabled on purpose. Re-enabling it (or
        // adding a second, working default beside it) would undo that decision.
        Assert.False(await SeedAsync(fx));

        using var after = fx.NewContext();
        Assert.False((await after.AdminUsers.SingleAsync()).IsActive);
    }
}
