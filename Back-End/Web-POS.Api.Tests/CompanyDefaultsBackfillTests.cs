using Api.DataBase;
using Api.Domain;
using Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Existing companies get the settings that were added after they were created —
/// and nothing they already have is touched.
///
/// <para>🚨 Why this exists. <see cref="CompanyDefaultsSeeder.SeedAsync"/> runs
/// ONCE, when a company is created. A key added to
/// <see cref="CompanyDefaultsSeeder.DefaultProperties"/> later never reached a
/// company that already existed — and a missing row does not mean "the seed
/// value". The till falls back to its own <c>kSettingDefaults</c>, which disagreed
/// with the seed on 43 keys. So two companies could behave differently for the
/// same setting purely by when they were created: an older one allowing negative
/// stock and voids without a reason, a newer one refusing both.</para>
///
/// <para>The rule these defend is the narrow one: ADD what is missing, never
/// overwrite what is there. A value an operator chose is not the backfill's to
/// change, even when it differs from the seed.</para>
/// </summary>
public class CompanyDefaultsBackfillTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;

    /// <summary>A company created before any settings existed — it has none.</summary>
    private readonly int _bare;

    /// <summary>A company with two settings an operator changed away from the seed.</summary>
    private readonly int _partial;

    /// <summary>A company created after every key existed — nothing is missing.</summary>
    private readonly int _complete;

    private static int SeededCount => CompanyDefaultsSeeder.DefaultProperties.Length;

    public CompanyDefaultsBackfillTests()
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

        var companies = Enumerable.Range(0, 3)
            .Select(i => Company.Create(
                $"Company {i}", 1, null, null, null, null, null, null,
                null, null, null, null, null, null, null, null))
            .ToList();
        db.Companies.AddRange(companies);
        db.SaveChanges();
        (_bare, _partial, _complete) = (companies[0].Id, companies[1].Id, companies[2].Id);

        // Deliberately values the seed does NOT hold: the seed says "true" and
        // "DH". If the backfill ever "helpfully" corrected these, these rows are
        // what would show it.
        db.ApplicationProperties.Add(
            ApplicationProperty.Create(_partial, "Order.PreventNegativeInventory", "false"));
        db.ApplicationProperties.Add(
            ApplicationProperty.Create(_partial, "CurrencySymbol", "€"));

        foreach (var (name, value) in CompanyDefaultsSeeder.DefaultProperties)
            db.ApplicationProperties.Add(ApplicationProperty.Create(_complete, name, value));

        db.SaveChanges();
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private async Task<int> BackfillAsync()
    {
        await using var db = new AppDbContext(_options);
        return await CompanyDefaultsSeeder.BackfillMissingPropertiesAsync(db);
    }

    private Dictionary<string, string?> SettingsOf(int companyId)
    {
        using var db = new AppDbContext(_options);
        return db.ApplicationProperties.AsNoTracking()
            .Where(p => p.CompanyId == companyId)
            .ToList()
            .ToDictionary(p => p.Name!, p => p.Value, StringComparer.OrdinalIgnoreCase);
    }

    // ── What it adds ─────────────────────────────────────────────────────────

    [Fact]
    public async Task A_company_with_no_settings_gets_every_default_at_the_seed_value()
    {
        await BackfillAsync();

        var settings = SettingsOf(_bare);
        Assert.Equal(SeededCount, settings.Count);
        foreach (var (name, value) in CompanyDefaultsSeeder.DefaultProperties)
            Assert.Equal(value, settings[name]);
    }

    [Fact]
    public async Task Only_the_missing_keys_are_added()
    {
        var added = await BackfillAsync();

        // Bare gets all of them, partial all but its two, complete none.
        Assert.Equal(SeededCount + (SeededCount - 2), added);
        Assert.Equal(SeededCount, SettingsOf(_partial).Count);
    }

    [Fact]
    public async Task A_company_that_already_has_everything_gains_nothing()
    {
        await BackfillAsync();

        var settings = SettingsOf(_complete);
        Assert.Equal(SeededCount, settings.Count);
    }

    // ── What it must never do ────────────────────────────────────────────────

    [Fact]
    public async Task A_value_an_operator_chose_is_never_overwritten()
    {
        // The whole reason it is add-only. This company allows negative stock and
        // prices in euros, both against the seed, and both are its call to make.
        await BackfillAsync();

        var settings = SettingsOf(_partial);
        Assert.Equal("false", settings["Order.PreventNegativeInventory"]);
        Assert.Equal("€", settings["CurrencySymbol"]);
    }

    [Fact]
    public async Task Running_it_again_adds_nothing()
    {
        // It runs on every startup; the second boot must be a no-op.
        await BackfillAsync();

        Assert.Equal(0, await BackfillAsync());
    }

    [Fact]
    public async Task A_retired_key_is_never_added_back()
    {
        // If a retired name were still in the seed, the backfill would re-add it
        // and the obsolete sweep would delete it again — on every single boot.
        await BackfillAsync();

        await using var db = new AppDbContext(_options);
        var names = await db.ApplicationProperties.AsNoTracking()
            .Select(p => p.Name!)
            .ToListAsync();
        Assert.DoesNotContain(names, n =>
            CompanyDefaultsSeeder.ObsoleteProperties.Contains(n, StringComparer.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Backfilled_rows_are_stamped_so_the_terminals_pull_them()
    {
        // Terminals pull settings as a delta (?modifiedAfter=). A row that lands
        // without a fresh LastModified sits in the database, correct and never
        // reached — the trap BrandAccentBackfillTests pins for the accent colour.
        var before = DateTime.UtcNow.AddSeconds(-5);

        await BackfillAsync();

        await using var db = new AppDbContext(_options);
        var stamps = await db.ApplicationProperties.AsNoTracking()
            .Where(p => p.CompanyId == _bare)
            .Select(p => p.LastModified)
            .ToListAsync();
        Assert.NotEmpty(stamps);
        Assert.All(stamps, s => Assert.True(s >= before, $"LastModified {s:O} predates the backfill"));
    }

    // ── The two lists it depends on ──────────────────────────────────────────

    [Fact]
    public void The_seeded_and_retired_lists_never_overlap()
    {
        var overlap = CompanyDefaultsSeeder.DefaultProperties
            .Select(p => p.Name)
            .Intersect(CompanyDefaultsSeeder.ObsoleteProperties, StringComparer.OrdinalIgnoreCase)
            .ToList();

        Assert.Empty(overlap);
    }

    [Fact]
    public void No_setting_is_seeded_twice()
    {
        // A duplicate name would make the seed value depend on list order.
        var duplicates = CompanyDefaultsSeeder.DefaultProperties
            .GroupBy(p => p.Name, StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key)
            .ToList();

        Assert.Empty(duplicates);
    }

    // ── The four keys retired on 2026-09-10 ──────────────────────────────────

    [Theory]
    [InlineData("App.EnableSounds")]
    [InlineData("Print.CashDrawer.Enabled")]
    [InlineData("Print.PrinterType")]
    [InlineData("Database.Backup.Version")]
    public async Task A_key_retired_on_2026_09_10_is_no_longer_seeded_and_is_swept(string key)
    {
        Assert.DoesNotContain(CompanyDefaultsSeeder.DefaultProperties,
            p => string.Equals(p.Name, key, StringComparison.OrdinalIgnoreCase));
        Assert.Contains(key, CompanyDefaultsSeeder.ObsoleteProperties);

        // A company seeded before the retirement still carries the row.
        await using (var db = new AppDbContext(_options))
        {
            db.ApplicationProperties.Add(ApplicationProperty.Create(_bare, key, "left over"));
            await db.SaveChangesAsync();
        }

        await using (var db = new AppDbContext(_options))
            await CompanyDefaultsSeeder.RemoveObsoletePropertiesAsync(db);

        await using var read = new AppDbContext(_options);
        Assert.False(await read.ApplicationProperties.AnyAsync(p => p.Name == key));
    }
}
