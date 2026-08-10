using Api.Master;
using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Admin;

/// <summary>
/// Provisions the admin portal's account table and its first account.
///
/// The Master DB has NO EF migrations — its schema comes from
/// docs/sql/master-db-schema.sql, run once by hand. This mirrors the pattern
/// already used for the Pillar-5 clone-audit table: an idempotent CREATE block
/// runs at startup so a machine that never ran the SQL file self-heals, and the
/// caller keeps it non-fatal so an absent or unreachable Master DB never blocks
/// boot.
///
/// The table must exist BEFORE the first request, not merely before first use:
/// the moment the API loads, EF emits every AdminUser column in every SELECT it
/// generates for that entity, so a missing table or column is an immediate
/// "Invalid object name" rather than a deferred one.
/// </summary>
public static class AdminUserSeeder
{
    public const string DefaultUsername = "Admin";
    public const string DefaultPassword = "Admin@123";
    private const string DefaultDisplayName = "Administrator";

    /// <summary>
    /// Idempotent DDL, kept character-for-character equivalent to the AdminUser
    /// block in docs/sql/master-db-schema.sql. Changing one means changing both.
    /// </summary>
    public const string EnsureTableSql = @"
        IF OBJECT_ID('dbo.AdminUser', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.AdminUser (
                Id                 INT IDENTITY(1,1) PRIMARY KEY,
                Username           NVARCHAR(100) NOT NULL,
                PasswordHash       NVARCHAR(255) NOT NULL,
                DisplayName        NVARCHAR(255) NULL,
                IsActive           BIT       NOT NULL CONSTRAINT DF_AdminUser_IsActive DEFAULT(1),
                MustChangePassword BIT       NOT NULL CONSTRAINT DF_AdminUser_MustChange DEFAULT(0),
                CreatedAt          DATETIME2 NOT NULL CONSTRAINT DF_AdminUser_CreatedAt DEFAULT(SYSUTCDATETIME()),
                LastLoginAt        DATETIME2 NULL,
                CONSTRAINT UQ_AdminUser_Username UNIQUE (Username)
            );
        END";

    public static Task EnsureTableAsync(MasterDbContext db, CancellationToken ct = default) =>
        db.Database.ExecuteSqlRawAsync(EnsureTableSql, ct);

    /// <summary>
    /// Creates the first admin account if — and only if — the table holds no users
    /// at all.
    ///
    /// The "no users at all" test is the whole idempotency guarantee, and it is
    /// deliberately not "no user named Admin": once any account exists the seeder
    /// is inert, so it can never resurrect a deleted Admin, reset a changed
    /// password, or re-enable a disabled account. Renaming the seeded account also
    /// keeps it inert.
    /// </summary>
    /// <returns>True when an account was created by this call.</returns>
    public static async Task<bool> SeedFirstAdminAsync(
        MasterDbContext db, ILogger logger, CancellationToken ct = default)
    {
        if (await db.AdminUsers.AnyAsync(ct))
            return false;

        db.AdminUsers.Add(new AdminUser
        {
            Username = DefaultUsername,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(DefaultPassword),
            DisplayName = DefaultDisplayName,
            IsActive = true,
            // The password is published in this source file, so the account is
            // only as safe as the first person to log in and change it.
            MustChangePassword = true,
            CreatedAt = DateTime.UtcNow,
        });

        await db.SaveChangesAsync(ct);

        logger.LogWarning(
            "SECURITY: the admin portal had no accounts, so the default account " +
            "'{username}' was created with the well-known password '{password}'. " +
            "Anyone who can reach {loginPath} can sign in with it. Change it now at " +
            "/admin/account/password — the portal will keep warning until you do.",
            DefaultUsername, DefaultPassword, AdminPortalAuth.LoginPath);

        return true;
    }
}
