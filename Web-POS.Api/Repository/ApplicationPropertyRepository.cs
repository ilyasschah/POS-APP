using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class ApplicationPropertyRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<ApplicationProperty>> GetAllAsync(int companyId)
        {
            return await _db.ApplicationProperties
                .AsNoTracking()
                .Where(p => p.CompanyId == companyId)
                .ToListAsync();
        }
        public async Task<ApplicationProperty?> GetByNameAsync(string name, int companyId)
        {
            return await _db.ApplicationProperties
                .AsNoTracking()
                .Where(p => p.CompanyId == companyId)
                .FirstOrDefaultAsync(p => p.Name == name && p.CompanyId == companyId);
        }
        public async Task<bool> ExistsAsync(string name, int companyId)
        {
            return await _db.ApplicationProperties
                .Where(p => p.CompanyId == companyId)
                .AnyAsync(p => p.Name.ToLower() == name.ToLower() && p.CompanyId == companyId);
        }
        public async Task AddAsync(ApplicationProperty entity)
        {
            _db.ApplicationProperties.Add(entity);
            await _db.SaveChangesAsync();
        }
        public async Task UpdateAsync(ApplicationProperty entity)
        {
            _db.ApplicationProperties.Update(entity);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(ApplicationProperty entity)
        {
            _db.ApplicationProperties.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
