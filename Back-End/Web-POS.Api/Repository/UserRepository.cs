using Api.DataBase;
using Api.Domain;
using Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository;

public class UserRepository
{
    private readonly AppDbContext _db;

    public UserRepository(AppDbContext db)
    {
        _db = db;
    }

    
    public async Task<List<UserDto>> GetAllUsersAsync(int companyId, string? deviceId, bool includeDisabled = false, DateTime? modifiedAfter = null)
    {
        var query = _db.Users
            .AsNoTracking()
            .Where(u => u.CompanyId == companyId && (includeDisabled || u.IsEnabled));

        if (modifiedAfter.HasValue)
        {
            var watermark = modifiedAfter.Value.Kind == DateTimeKind.Utc
                ? modifiedAfter.Value
                : modifiedAfter.Value.ToUniversalTime();
            query = query.Where(u => u.LastModified > watermark);
        }

        return await query
            .Select(u => new
            {
                User = u,
                Pin = _db.UserDevicePins.FirstOrDefault(p => p.UserId == u.Id && p.DeviceId == deviceId)
            })
            .Select(x => new UserDto
            {
                Id = x.User.Id,
                CompanyId = x.User.CompanyId,
                FirstName = x.User.FirstName,
                LastName = x.User.LastName,
                Username = x.User.Username,
                AccessLevel = x.User.AccessLevel,
                IsEnabled = x.User.IsEnabled,
                Email = x.User.Email,
                HasPinForThisDevice = x.Pin != null,
                HashedPin = x.Pin != null ? x.Pin.HashedPin : null,
                LastModified = x.User.LastModified
            })
            .ToListAsync();
    }
    public async Task<User?> GetByIdAsync(int id, int companyId)
    {
        return await _db.Users
            .AsQueryable()
            .FirstOrDefaultAsync(u => u.Id == id && u.CompanyId == companyId);
    }

    public async Task<User?> GetByUsernameAsync(string username, int companyId)
    {
        return await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Username == username && u.CompanyId == companyId);
    }

    /// <summary>
    /// Looks up a user by email across all companies. Used by device
    /// registration login where no companyId is known yet.
    /// </summary>
    public async Task<User?> GetByEmailAnyCompanyAsync(string email)
    {
        return await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Email == email);
    }

    public async Task<bool> ExistsAsync(string username, int companyId)
    {
        return await _db.Users.AnyAsync(u => u.Username == username && u.CompanyId == companyId);
    }

    public async Task AddAsync(User entity)
    {
        _db.Users.Add(entity);
        await _db.SaveChangesAsync();
    }

    public async Task<bool> UpdateAsync(User entity)
    {
        _db.Users.Update(entity);
        await _db.SaveChangesAsync();
        return true;
    }

    /// <summary>
    /// Deletes a user and the device PINs that belong to them.
    ///
    /// 🚨 The PINs have to go FIRST. `UserDevicePins.UserId` carries a real FK
    /// (`FK_UserDevicePins_User`) and the live database declares it NO ACTION —
    /// the EF migration that created the table asked for Cascade, but the table
    /// in `web-pos` was built by hand and does not match. So SQL Server refuses
    /// the delete, and because the row EF is removing is the User, it surfaces
    /// as the same error code (547) a real sales record produces. That is how
    /// "this user has a document related to their name" came to be shown for a
    /// user who had nothing but a till PIN.
    ///
    /// A PIN is a per-terminal CREDENTIAL, not history: it is how that person
    /// unlocked a till, and it means nothing once the person is gone. Sales,
    /// payments, bookings and voids are the opposite — those still block the
    /// delete, on purpose.
    ///
    /// ⚠️ Both statements share ONE transaction. Deleting the PINs first and
    /// letting the User delete fail on its own would log the person out of
    /// every terminal they use and then report that nothing was deleted.
    /// </summary>
    public async Task<bool> DeleteAsync(int id, int companyId)
    {
        if (await GetByIdAsync(id, companyId) == null)
        {
            throw new InvalidOperationException("User not found.");
        }

        var strategy = _db.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            // Re-read inside the strategy: on a retry the tracked instance from
            // the failed attempt is stale, and Remove() on it would replay the
            // old state.
            _db.ChangeTracker.Clear();

            await using var tx = await _db.Database.BeginTransactionAsync();

            var entity = await GetByIdAsync(id, companyId)
                ?? throw new InvalidOperationException("User not found.");

            await _db.UserDevicePins
                .Where(p => p.UserId == id && p.CompanyId == companyId)
                .ExecuteDeleteAsync();

            _db.Users.Remove(entity);
            await _db.SaveChangesAsync();

            await tx.CommitAsync();
        });

        return true;
    }
}
