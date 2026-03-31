using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository;

public class UserRepository
{
    private readonly AppDbContext _db;

    public UserRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<User>> GetAllAsync(int companyId)
    {
        return await _db.Users
            .AsNoTracking()
            .Where(u => u.CompanyId == companyId)
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
