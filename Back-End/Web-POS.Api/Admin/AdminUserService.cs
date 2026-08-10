using Api.Master;
using Api.Master.Domain;
using BCrypt.Net;
using Microsoft.EntityFrameworkCore;

namespace Api.Admin;

/// <summary>
/// Credential checks for the admin portal. The only place that reads or writes an
/// <see cref="AdminUser"/> password.
/// </summary>
public sealed class AdminUserService
{
    /// <summary>
    /// A real BCrypt hash of a value nobody has, verified against on the
    /// "no such user" path.
    ///
    /// Without it the portal is trivially enumerable *despite* the generic error
    /// message: an unknown username returns in microseconds while a known one
    /// spends ~100ms hashing, and that gap is visible to anyone timing responses.
    /// Verifying against this hash makes both paths cost the same. It is generated
    /// at startup rather than hardcoded so the work factor always matches whatever
    /// <c>HashPassword</c> currently defaults to — a cheaper dummy hash would
    /// reopen the same gap.
    /// </summary>
    private static readonly string TimingEqualizerHash =
        BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N"));

    private readonly MasterDbContext _db;

    public AdminUserService(MasterDbContext db) => _db = db;

    /// <summary>
    /// Returns the account when the credentials are valid and the account is
    /// active, otherwise null. The caller must NOT distinguish the reasons to the
    /// operator — "no such user", "wrong password" and "disabled" are one message.
    /// </summary>
    public async Task<AdminUser?> ValidateCredentialsAsync(
        string? username, string? password, CancellationToken ct = default)
    {
        var candidate = username?.Trim();

        var user = string.IsNullOrEmpty(candidate)
            ? null
            : await _db.AdminUsers.FirstOrDefaultAsync(u => u.Username == candidate, ct);

        // Runs on every path, including the ones already known to fail — see
        // TimingEqualizerHash. Do not short-circuit any of them.
        var passwordMatches = VerifyPassword(password, user?.PasswordHash);

        if (user is null || !passwordMatches || !user.IsActive)
            return null;

        return user;
    }

    public async Task RecordLoginAsync(AdminUser user, CancellationToken ct = default)
    {
        user.LastLoginAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }

    public Task<AdminUser?> FindByIdAsync(int id, CancellationToken ct = default) =>
        _db.AdminUsers.FirstOrDefaultAsync(u => u.Id == id, ct);

    /// <summary>
    /// Re-checks the current password before replacing it, and clears
    /// <see cref="AdminUser.MustChangePassword"/> on success.
    /// </summary>
    /// <returns>False when the current password does not match.</returns>
    public async Task<bool> ChangePasswordAsync(
        AdminUser user, string? currentPassword, string newPassword, CancellationToken ct = default)
    {
        if (!VerifyPassword(currentPassword, user.PasswordHash))
            return false;

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        user.MustChangePassword = false;
        await _db.SaveChangesAsync(ct);
        return true;
    }

    /// <summary>
    /// BCrypt's own comparison is fixed-time (<c>SecureEquals</c>), so it does not
    /// leak how much of the hash matched. A null/absent stored hash still costs a
    /// full verify against <see cref="TimingEqualizerHash"/>.
    /// </summary>
    public static bool VerifyPassword(string? password, string? storedHash)
    {
        var hash = string.IsNullOrWhiteSpace(storedHash) ? TimingEqualizerHash : storedHash;
        try
        {
            return BCrypt.Net.BCrypt.Verify(password ?? string.Empty, hash);
        }
        catch (SaltParseException)
        {
            // A corrupt or non-BCrypt value in the column must fail the login, not
            // 500 the page. Verify() throws almost immediately on a malformed hash,
            // so burn the equivalent work before returning — otherwise a broken
            // account answers measurably faster than a healthy one.
            BCrypt.Net.BCrypt.Verify(password ?? string.Empty, TimingEqualizerHash);
            return false;
        }
    }
}
