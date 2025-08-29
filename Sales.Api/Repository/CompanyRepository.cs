using Microsoft.EntityFrameworkCore;
using Sales.Api.DataBase;
using Sales.Api.Domain;

namespace Sales.Api.Repository;

public class CompanyRepository
{
    public readonly AppDbContext _db;

    public CompanyRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<Company>> GetAllAsync()
    {
        return await _db.Companies
            .AsNoTracking()
            .Include(c => c.Country)
            .ToListAsync();
    }

    public async Task<Company?> GetByIdAsync(int id)
    {
        return await _db.Companies
            .Include(c => c.Country)
            .FirstOrDefaultAsync(c => c.Id == id);
    }

    public async Task<Company?> GetByNameAsync(string name)
    {
        return await _db.Companies
            .FirstOrDefaultAsync(c => c.Name == name);
    }

    public bool Exists(string name)
    {
        return _db.Companies.Any(c => c.Name == name);
    }

    public async Task AddAsync(Company entity)
    {
        _db.Companies.Add(entity);
        await _db.SaveChangesAsync();
    }

    public async Task UpdateAsync(Company entity)
    {
        _db.Companies.Update(entity);
        await _db.SaveChangesAsync();
    }

    public async Task DeleteAsync(Company entity)
    {
        _db.Companies.Remove(entity);
        await _db.SaveChangesAsync();
    }
}
