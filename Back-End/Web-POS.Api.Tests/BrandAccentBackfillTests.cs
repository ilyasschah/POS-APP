using Api.DataBase;
using Api.Domain;
using Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The one-time move from the pre-rollout blue accent to the brand coral.
///
/// Why a backfill exists at all: <see cref="CompanyDefaultsSeeder.SeedAsync"/>
/// only ever ADDS a missing key, so every company created before the rollout
/// kept the blue it was seeded with and would have kept it forever. New
/// companies got coral; the tills actually in service did not.
///
/// 🚨 The risk this pins is the opposite one. A backfill that "makes everything
/// consistent" would also erase the accent an operator deliberately picked, and
/// they would have no way to know why their green till turned red overnight.
/// So the match is exact: only a row still holding the literal old default is
/// touched. That narrowness is the feature, and it is what these tests defend.
///
/// The second trap is invisible rather than destructive. ApplicationProperty is
/// an <see cref="ISyncableEntity"/> and terminals pull deltas with
/// <c>?modifiedAfter=</c>. Changing Value without bumping LastModified would
/// leave the new accent sitting in the database, correct and unreachable, while
/// every till kept rendering the cached blue.
/// </summary>
public class BrandAccentBackfillTests : IDisposable
{
    private const string LegacyBlue = "#2196F3";
    private const string LegacyCoral = "#FF416C";
    private const string BrandRed = "#A4161A";
    private const string AccentKey = "Theme_AccentColor";

    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;

    public BrandAccentBackfillTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        using var db = new AppDbContext(_options);
        db.Database.EnsureCreated();

        // ApplicationProperty hangs off Company, which hangs off Country.
        db.Countries.Add(new Country { Id = 1, Name = "Morocco", Code = "MA" });
        db.SaveChanges();
        for (var i = 0; i < 4; i++)
        {
            db.Companies.Add(Company.Create(
                $"Company {i}", 1, null, null, null, null, null, null,
                null, null, null, null, null, null, null, null));
        }
        db.SaveChanges();
    }

    public void Dispose() => _connection.Dispose();

    /// <summary>
    /// Inserts an accent row, optionally back-dated.
    ///
    /// The back-dating has to go through raw SQL: AppDbContext.SaveChanges
    /// stamps LastModified on every Added or Modified ISyncableEntity, so a
    /// timestamp assigned on the entity is overwritten on the way to the
    /// database. That stamping is exactly the behaviour these tests exist to
    /// verify, so the seeding has to step around it rather than disable it.
    /// </summary>
    private void GiveAccent(int companyId, string value, DateTime? modified = null)
    {
        using var db = new AppDbContext(_options);
        var row = ApplicationProperty.Create(companyId, AccentKey, value);
        db.ApplicationProperties.Add(row);
        db.SaveChanges();

        if (modified is null) return;
        db.Database.ExecuteSqlInterpolated(
            $"UPDATE ApplicationProperty SET LastModified = {modified.Value} WHERE Id = {row.Id}");
    }

    private ApplicationProperty AccentOf(int companyId)
    {
        using var db = new AppDbContext(_options);
        return db.ApplicationProperties
            .Single(p => p.CompanyId == companyId && p.Name == AccentKey);
    }

    [Fact]
    public async Task A_company_still_on_the_old_default_moves_to_the_brand()
    {
        GiveAccent(1, LegacyBlue);

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.Equal(BrandRed, AccentOf(1).Value);
    }

    [Fact]
    public async Task A_company_on_the_PREVIOUS_brand_moves_too()
    {
        // The brand has moved twice: blue, then coral, then blood red. A company
        // created during the coral window is just as stranded as one from the
        // blue era, and both are still on a value nobody chose for themselves.
        GiveAccent(1, LegacyCoral);

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.Equal(BrandRed, AccentOf(1).Value);
    }

    [Fact]
    public async Task An_operator_chosen_accent_is_left_alone()
    {
        // The whole point of matching exactly. Someone picked this green; it is
        // not the product's job to overrule them for the sake of a brand.
        GiveAccent(1, "#4CAF50");
        GiveAccent(2, "#9C27B0");
        GiveAccent(3, LegacyBlue);

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.Equal("#4CAF50", AccentOf(1).Value);
        Assert.Equal("#9C27B0", AccentOf(2).Value);
        Assert.Equal(BrandRed, AccentOf(3).Value);
    }

    [Fact]
    public async Task The_change_is_published_to_terminals()
    {
        // Delta sync is the only way a till learns anything. A row rewritten
        // without a fresh LastModified is a change no terminal will ever ask for.
        var stale = new DateTime(2020, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        GiveAccent(1, LegacyBlue, stale);

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.True(AccentOf(1).LastModified > stale,
            "the accent changed but no terminal would ever be told");
    }

    [Fact]
    public async Task Untouched_rows_keep_their_timestamp()
    {
        // The mirror of the above: bumping LastModified on a row that did NOT
        // change would push a pointless write to every till on every startup.
        var stale = new DateTime(2020, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        GiveAccent(1, "#4CAF50", stale);

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.Equal(stale, AccentOf(1).LastModified);
    }

    [Fact]
    public async Task Running_it_again_changes_nothing()
    {
        // It runs on EVERY startup, so a second pass must be a genuine no-op —
        // otherwise every reboot re-times-stamps the row and every till re-syncs
        // a setting that did not change.
        GiveAccent(1, LegacyBlue);

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);
        var afterFirst = AccentOf(1).LastModified;

        using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.Equal(BrandRed, AccentOf(1).Value);
        Assert.Equal(afterFirst, AccentOf(1).LastModified);
    }

    [Fact]
    public async Task An_empty_database_is_a_no_op()
    {
        using var db = new AppDbContext(_options);
        await CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);

        Assert.Empty(db.ApplicationProperties);
    }

    [Fact]
    public void The_backfill_target_matches_what_new_companies_are_seeded()
    {
        // The backfill reads the brand from DefaultProperties rather than
        // repeating it, so these cannot drift. This asserts the seeded value is
        // what the rest of the product expects, which is the half a compiler
        // cannot check.
        var seeded = CompanyDefaultsSeeder.DefaultProperties
            .Single(p => p.Name == AccentKey).Value;

        Assert.Equal(BrandRed, seeded);
        Assert.NotEqual(LegacyBlue, seeded);
        Assert.NotEqual(LegacyCoral, seeded);
    }
}
