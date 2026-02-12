using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository;

public class UserRepository
{
    public readonly AppDbContext _db;

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

    public async Task<User?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
    {
        var q = _db.Users.AsQueryable();
        if (!trackEntity) q = q.AsNoTracking();
        return await q
            .FirstOrDefaultAsync(u => u.Id == id && u.CompanyId == companyId);
    }

    public async Task<User?> GetByIdAsync(int id)
    {
        return await _db.Users
            .FirstOrDefaultAsync(u => u.Id == id);
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

    public async Task UpdateAsync(User entity)
    {
        _db.Users.Update(entity);
        await _db.SaveChangesAsync();
    }

    public async Task DeleteAsync(User entity)
    {
        _db.Users.Remove(entity);
        await _db.SaveChangesAsync();
    }
}
