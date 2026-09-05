using Api.DataBase;
using Microsoft.EntityFrameworkCore;

namespace Api.Startup;

/// <summary>
/// Everything that must be true of the databases before the first request is
/// served. Moved out of Program.cs, which is a wiring file, not a place for a
/// hundred lines of procedure.
///
/// House rules for everything in here:
/// * <b>Idempotent</b> — it runs on every single startup.
/// * <b>Non-fatal</b> — an absent or unreachable database must never stop the API
///   from booting. Each failure is logged loudly and recorded on the report so the
///   banner can say so out loud, instead of the operator discovering it later.
/// * <b>Quiet when it works.</b> The success paths log at Debug. Four lines of
///   "verified" on every boot train you to stop reading the console, which is how
///   a real warning goes unnoticed.
/// </summary>
public static class DatabaseBootstrapper
{
    public static async Task<StartupReport> RunAsync(
        WebApplication app, ILogger logger)
    {
        var report = new StartupReport();

        await EnsureTenantDatabaseAsync(app, logger, report);
        await EnsureMasterDatabaseAsync(app, logger, report);

        return report;
    }

    /// <summary>
    /// The POS (tenant) database: reachability plus the global reference data the
    /// app cannot start empty-handed.
    /// </summary>
    private static async Task EnsureTenantDatabaseAsync(
        WebApplication app, ILogger logger, StartupReport report)
    {
        using var scope = app.Services.CreateScope();
        try
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            report.AppDatabaseConnected = db.Database.CanConnect();

            if (!report.AppDatabaseConnected)
            {
                logger.LogError(
                    "POS database is UNREACHABLE. Check ConnectionStrings:DefaultConnection, " +
                    "and that the MSSQLSERVER service is running (its startup type is Manual, " +
                    "so it is simply not started after a reboot).");
                return;
            }

            // Re-seeds if a wipe emptied them, so the app can never start without
            // the static data it needs.
            await Api.Services.GlobalDefaultsSeeder.SeedAsync(db);
            logger.LogDebug("Global reference data verified/seeded.");

            // Backfills security keys added in app updates onto existing companies.
            // Only adds what is missing — never touches admin-customised levels.
            await Api.Services.CompanyDefaultsSeeder.BackfillSecurityKeysAsync(db);
            logger.LogDebug("Security keys verified/backfilled for existing companies.");

            // Gives companies that predate the nomenclature a rule set, translating
            // their old Scale.Barcode.* settings so labels already on the shelf
            // keep decoding. Skips any company that already has rules.
            await Api.Services.BarcodeRuleSeeder.BackfillAsync(db);
            logger.LogDebug("Barcode rules verified/backfilled for existing companies.");

            // Sweeps ApplicationProperty rows for settings that have since been
            // fully retired from the app (e.g. App.IndustryMode) — SeedAsync only
            // ever adds a missing key, so a removed one otherwise lingers forever
            // for any company seeded before the removal.
            await Api.Services.CompanyDefaultsSeeder.RemoveObsoletePropertiesAsync(db);
            logger.LogDebug("Obsolete application properties swept.");

            // Moves companies still on the pre-rollout blue accent onto the brand
            // coral. Touches ONLY rows still holding the old default, so an
            // operator who picked their own colour keeps it.
            await Api.Services.CompanyDefaultsSeeder.BackfillBrandAccentAsync(db);
            logger.LogDebug("Brand accent verified/backfilled for existing companies.");
        }
        catch (Exception ex)
        {
            report.AppDatabaseConnected = false;
            logger.LogError(ex, "POS database check / global seed failed.");
        }
    }

    /// <summary>
    /// The Master (control-plane) database. It has NO EF migrations — its schema
    /// comes from docs/sql/master-db-schema.sql, run once by hand — so the additive
    /// tables are self-healed here for any machine that never ran that file.
    /// </summary>
    private static async Task EnsureMasterDatabaseAsync(
        WebApplication app, ILogger logger, StartupReport report)
    {
        using var scope = app.Services.CreateScope();
        try
        {
            var master = scope.ServiceProvider.GetRequiredService<Api.Master.MasterDbContext>();

            report.MasterDatabaseConnected = master.Database.CanConnect();
            if (!report.MasterDatabaseConnected)
            {
                logger.LogWarning(
                    "Master (control-plane) database is UNREACHABLE. Licensing, device seats " +
                    "and the /admin portal are unavailable until it is back; the POS API's own " +
                    "endpoints are unaffected.");
                return;
            }

            await EnsureCloneAuditTableAsync(master);
            logger.LogDebug("Pillar 5 clone-audit table verified.");

            // Caught separately from everything above: "the Master DB is down" and
            // "this login cannot create tables" look identical from the portal (every
            // sign-in fails) but need completely different fixes, and the second is
            // the likely one on a server where the API's SQL login is not db_owner.
            //
            // ⚠️ This must complete BEFORE the pipeline serves anything. From the
            // moment the API loads, EF emits every AdminUser column in every query
            // for that entity — a missing table is an immediate "Invalid object
            // name", not a deferred one.
            try
            {
                await Api.Admin.AdminUserSeeder.EnsureTableAsync(master);
                await Api.Admin.AdminUserSeeder.SeedFirstAdminAsync(
                    master, logger,
                    app.Configuration[Api.Admin.AdminUserSeeder.SeedPasswordConfigKey]);

                report.AdminPortalReady = true;

                // Surfaced on every boot, not just the one that seeded it: an account
                // left on the published default is the single most useful thing the
                // console can tell you about the portal.
                report.AdminPortalOnDefaultPassword = await master.AdminUsers
                    .AnyAsync(u => u.IsActive && u.MustChangePassword);

                logger.LogDebug("Admin portal account table verified.");
            }
            catch (Exception ex)
            {
                report.AdminPortalReady = false;
                logger.LogError(ex,
                    "ADMIN PORTAL UNUSABLE: could not create or seed dbo.AdminUser in the " +
                    "Master database. Every /admin sign-in will fail until this is fixed. " +
                    "If the API's SQL login lacks CREATE TABLE rights, run the AdminUser " +
                    "block from docs/sql/master-db-schema.sql against the Master DB by hand " +
                    "and restart — the seed then runs on the next boot.");
            }
        }
        catch (Exception ex)
        {
            report.MasterDatabaseConnected = false;
            logger.LogWarning(ex, "Master database check skipped (unreachable?).");
        }
    }

    /// <summary>Pillar 5 — the clone / duplication audit ledger.</summary>
    private static Task EnsureCloneAuditTableAsync(Api.Master.MasterDbContext master) =>
        master.Database.ExecuteSqlRawAsync(@"
            IF OBJECT_ID('dbo.TransactionAudit', 'U') IS NULL
            BEGIN
                CREATE TABLE dbo.TransactionAudit (
                    Id            INT IDENTITY(1,1) PRIMARY KEY,
                    TenantId      INT NOT NULL,
                    CompanyId     INT NOT NULL,
                    ClientTxnId   NVARCHAR(128) NOT NULL,
                    FirstDeviceId NVARCHAR(128) NOT NULL,
                    LastDeviceId  NVARCHAR(128) NULL,
                    SeenCount     INT NOT NULL DEFAULT(1),
                    IsFlagged     BIT NOT NULL DEFAULT(0),
                    FlagReason    NVARCHAR(64) NULL,
                    FirstSeenUtc  DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME()),
                    LastSeenUtc   DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME())
                );
                CREATE UNIQUE INDEX UX_TransactionAudit_Tenant_Txn
                    ON dbo.TransactionAudit (TenantId, ClientTxnId);
            END");
}
