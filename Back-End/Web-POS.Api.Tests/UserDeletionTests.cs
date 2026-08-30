using Api.DataBase;
using Api.Domain;
using Api.Repository;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Deleting a user, and the two things that must be true of it.
///
/// 🚨 The bug these were written for (2026-08-29): deleting a user from the
/// admin portal failed with SQL error 547 on <c>FK_UserDevicePins_User</c>, and
/// the portal reported "this user has a document related to their name" — so
/// the operator went looking for a sale that did not exist. The user's only tie
/// was a till PIN.
///
/// A device PIN is a per-terminal CREDENTIAL, not history. It means nothing
/// once the person is gone, so it is deleted with them. Sales, payments,
/// bookings, voids and starting cash are history and still block the delete on
/// purpose — a receipt has to keep naming who rang it up.
/// </summary>
public class UserDeletionTests : IDisposable
{
    private const int CompanyId = 1;

    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;

    public UserDeletionTests()
    {
        // A real relational database rather than the in-memory provider: this is
        // about foreign keys and a transaction rolling back, and the in-memory
        // provider enforces neither. Microsoft.Data.Sqlite turns
        // `PRAGMA foreign_keys` on for each connection.
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        using var db = new AppDbContext(_options);
        db.Database.EnsureCreated();

        // User -> Company -> Country are all real foreign keys, and the point of
        // using SQLite here is that they are enforced. Seed the chain the user
        // hangs off before any test runs.
        db.Countries.Add(new Country { Id = 1, Name = "Morocco", Code = "MA" });
        db.SaveChanges();
        db.Companies.Add(Company.Create(
            "Test Co", 1, null, null, null, null, null, null,
            null, null, null, null, null, null, null, null));
        db.SaveChanges();

        // 🚨 EnsureCreated builds the schema from the EF MODEL, and the model
        // does not describe the live database. Nothing configures these
        // relationships, so EF's convention applies and a required FK defaults
        // to CASCADE. The real `web-pos` database declares every one of them
        // NO ACTION — it was built by hand-written SQL rather than by these
        // migrations, and the constraint NAMES give it away: the migration asks
        // for `FK_UserDevicePins_User_UserId`, the database has
        // `FK_UserDevicePins_User`.
        //
        // Left alone, SQLite would cascade a user's sales history away instead
        // of refusing the delete, and the two "blocked" tests below would pass
        // for the wrong reason. This trigger puts production's rule back.
        //
        // ⚠️ The divergence itself is worth fixing at the source: an EF model
        // that believes it may cascade-delete Documents and Payments is one
        // loaded navigation property away from doing it, and only the database
        // constraint is stopping it today.
        db.Database.ExecuteSqlRaw(
            @"CREATE TRIGGER user_delete_blocked_by_history
              BEFORE DELETE ON ""User""
              FOR EACH ROW
              WHEN EXISTS (SELECT 1 FROM StartingCash WHERE UserId = OLD.Id)
              BEGIN
                  SELECT RAISE(ABORT, 'FK_StartingCash_User');
              END;");
    }

    public void Dispose() => _connection.Dispose();

    private AppDbContext NewContext() => new(_options);

    private int SeedUser(string username = "cashier")
    {
        using var db = NewContext();
        var user = User.Create(CompanyId, "Test", "User", username, "hash", 1, true, null);
        db.Users.Add(user);
        db.SaveChanges();
        return user.Id;
    }

    private void SeedPin(int userId, string deviceId)
    {
        using var db = NewContext();
        db.UserDevicePins.Add(UserDevicePin.Create(userId, CompanyId, deviceId, "hashed-pin"));
        db.SaveChanges();
    }

    private void SeedStartingCash(int userId)
    {
        using var db = NewContext();
        db.StartingCashes.Add(new StartingCash
        {
            CompanyId = CompanyId,
            UserId = userId,
            Amount = 100m,
            DateCreated = DateTime.UtcNow,
        });
        db.SaveChanges();
    }

    private int PinCount(int userId)
    {
        using var db = NewContext();
        return db.UserDevicePins.Count(p => p.UserId == userId);
    }

    private bool UserExists(int userId)
    {
        using var db = NewContext();
        return db.Users.Any(u => u.Id == userId);
    }

    [Fact]
    public async Task A_user_whose_only_tie_is_a_till_pin_can_be_deleted()
    {
        var userId = SeedUser();
        SeedPin(userId, "terminal-a");
        SeedPin(userId, "terminal-b");

        using (var db = NewContext())
        {
            await new UserRepository(db).DeleteAsync(userId, CompanyId);
        }

        Assert.False(UserExists(userId));
        Assert.Equal(0, PinCount(userId));
    }

    [Fact]
    public async Task Another_users_pins_are_left_alone()
    {
        var doomed = SeedUser("leaver");
        var keeper = SeedUser("stayer");
        SeedPin(doomed, "terminal-a");
        SeedPin(keeper, "terminal-a");

        using (var db = NewContext())
        {
            await new UserRepository(db).DeleteAsync(doomed, CompanyId);
        }

        Assert.Equal(0, PinCount(doomed));
        Assert.Equal(1, PinCount(keeper));
        Assert.True(UserExists(keeper));
    }

    [Fact]
    public async Task Sales_history_still_blocks_the_delete()
    {
        var userId = SeedUser();
        SeedStartingCash(userId);

        using var db = NewContext();
        await Assert.ThrowsAnyAsync<Exception>(
            () => new UserRepository(db).DeleteAsync(userId, CompanyId));

        Assert.True(UserExists(userId), "history must keep naming who rang it up");
    }

    [Fact]
    public async Task A_blocked_delete_leaves_the_till_pins_intact()
    {
        // 🚨 The reason the two statements share one transaction. Deleting the
        // PINs first and letting the User delete fail on its own would sign the
        // person out of every terminal they use and then report that nothing
        // was deleted — the worst of both outcomes, and invisible until someone
        // cannot open a till.
        var userId = SeedUser();
        SeedPin(userId, "terminal-a");
        SeedPin(userId, "terminal-b");
        SeedStartingCash(userId);

        using (var db = NewContext())
        {
            await Assert.ThrowsAnyAsync<Exception>(
                () => new UserRepository(db).DeleteAsync(userId, CompanyId));
        }

        Assert.True(UserExists(userId));
        Assert.Equal(2, PinCount(userId));
    }

    [Fact]
    public async Task Deleting_an_unknown_user_says_so_rather_than_reporting_success()
    {
        using var db = NewContext();
        var repository = new UserRepository(db);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => repository.DeleteAsync(4242, CompanyId));
    }

    [Fact]
    public async Task A_user_of_another_company_is_not_reachable()
    {
        var userId = SeedUser();

        using var db = NewContext();
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => new UserRepository(db).DeleteAsync(userId, CompanyId + 1));

        Assert.True(UserExists(userId));
    }
}
