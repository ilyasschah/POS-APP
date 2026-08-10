using Api.Admin;
using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The login decision itself. Every "returns null" case below renders as the same
/// message on the form (LoginModel.GenericFailure) — these tests pin that the
/// SERVICE cannot tell them apart either, so nothing downstream can leak which
/// one happened.
/// </summary>
public class AdminUserServiceTests
{
    private const string GoodPassword = "s3cret-passphrase";

    private static async Task<MasterDbFixture> WithUserAsync(
        string username = "Admin", bool isActive = true, string? hash = null)
    {
        var fx = new MasterDbFixture();
        using var db = fx.NewContext();
        db.AdminUsers.Add(new AdminUser
        {
            Username = username,
            PasswordHash = hash ?? BCrypt.Net.BCrypt.HashPassword(GoodPassword),
            DisplayName = "Administrator",
            IsActive = isActive,
            MustChangePassword = true,
        });
        await db.SaveChangesAsync();
        return fx;
    }

    [Fact]
    public async Task Accepts_the_right_password()
    {
        using var fx = await WithUserAsync();
        using var db = fx.NewContext();

        var user = await new AdminUserService(db).ValidateCredentialsAsync("Admin", GoodPassword);

        Assert.NotNull(user);
        Assert.Equal("Admin", user!.Username);
    }

    [Theory]
    [InlineData("Admin", "wrong-password")]   // right user, wrong password
    [InlineData("Admin", "")]                 // empty password
    [InlineData("nobody", GoodPassword)]      // no such user
    [InlineData("", GoodPassword)]            // empty username
    [InlineData(null, GoodPassword)]          // absent username
    [InlineData("Admin", null)]               // absent password
    public async Task Rejects_everything_else(string? username, string? password)
    {
        using var fx = await WithUserAsync();
        using var db = fx.NewContext();

        Assert.Null(await new AdminUserService(db).ValidateCredentialsAsync(username, password));
    }

    [Fact]
    public async Task Rejects_a_disabled_account_holding_the_correct_password()
    {
        using var fx = await WithUserAsync(isActive: false);
        using var db = fx.NewContext();

        Assert.Null(await new AdminUserService(db).ValidateCredentialsAsync("Admin", GoodPassword));
    }

    [Fact]
    public async Task A_corrupt_stored_hash_fails_the_login_instead_of_throwing()
    {
        // Anything that is not a BCrypt string makes BCrypt.Verify throw
        // SaltParseException. Unhandled, that is a 500 on the login page — which
        // both breaks the portal and confirms the username exists.
        using var fx = await WithUserAsync(hash: "not-a-bcrypt-hash");
        using var db = fx.NewContext();

        Assert.Null(await new AdminUserService(db).ValidateCredentialsAsync("Admin", GoodPassword));
    }

    [Fact]
    public async Task Change_password_replaces_the_hash_and_clears_the_default_warning()
    {
        using var fx = await WithUserAsync();
        const string next = "a-brand-new-passphrase";

        using (var db = fx.NewContext())
        {
            var svc = new AdminUserService(db);
            var user = await db.AdminUsers.SingleAsync();
            Assert.True(await svc.ChangePasswordAsync(user, GoodPassword, next));
        }

        using var after = fx.NewContext();
        var service = new AdminUserService(after);

        Assert.Null(await service.ValidateCredentialsAsync("Admin", GoodPassword));
        var signedIn = await service.ValidateCredentialsAsync("Admin", next);
        Assert.NotNull(signedIn);
        Assert.False(signedIn!.MustChangePassword);
    }

    [Fact]
    public async Task Change_password_refuses_a_wrong_current_password_and_changes_nothing()
    {
        using var fx = await WithUserAsync();

        using (var db = fx.NewContext())
        {
            var user = await db.AdminUsers.SingleAsync();
            Assert.False(await new AdminUserService(db)
                .ChangePasswordAsync(user, "not-my-password", "whatever-comes-next"));
        }

        // The old password must still work — a refused change that quietly wrote the
        // new hash anyway would lock the operator out with no error on screen.
        using var after = fx.NewContext();
        Assert.NotNull(await new AdminUserService(after).ValidateCredentialsAsync("Admin", GoodPassword));
        Assert.Null(await new AdminUserService(after).ValidateCredentialsAsync("Admin", "whatever-comes-next"));
    }

    [Fact]
    public async Task Records_the_login_timestamp()
    {
        using var fx = await WithUserAsync();
        using var db = fx.NewContext();
        var svc = new AdminUserService(db);

        var user = await svc.ValidateCredentialsAsync("Admin", GoodPassword);
        Assert.Null(user!.LastLoginAt);

        await svc.RecordLoginAsync(user);

        using var after = fx.NewContext();
        Assert.NotNull((await after.AdminUsers.SingleAsync()).LastLoginAt);
    }
}
