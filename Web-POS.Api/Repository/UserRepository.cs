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

    public async Task<bool> DeleteAsync(int id, int companyId)
    {
        var entity = await GetByIdAsync(id, companyId);
        if (entity == null)
        {
            throw new InvalidOperationException("User not found.");
        }
        _db.Users.Remove(entity);
        await _db.SaveChangesAsync();
        return true;
    }
}
