using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class ApplicationPropertyRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<ApplicationProperty>> GetAllAsync(int companyId, DateTime? modifiedAfter = null)
        {
            var query = _db.ApplicationProperties
                .AsNoTracking()
                .Where(p => p.CompanyId == companyId);

            if (modifiedAfter.HasValue)
            {
                var watermark = modifiedAfter.Value.Kind == DateTimeKind.Utc
                    ? modifiedAfter.Value
                    : modifiedAfter.Value.ToUniversalTime();
                query = query.Where(p => p.LastModified > watermark);
            }

            return await query
                .Include(p => p.Company)
                .ToListAsync();
        }

        public async Task<ApplicationProperty?> GetByIdAsync(int id, int companyId)
        {
            return await _db.ApplicationProperties
                .Include(p => p.Company)
                .FirstOrDefaultAsync(p => p.Id == id && p.CompanyId == companyId);
        }

        public async Task<ApplicationProperty?> GetByNameAsync(string name, int companyId)
        {
            return await _db.ApplicationProperties
                .Include(p => p.Company)
                .FirstOrDefaultAsync(p => p.Name!.ToLower() == name.ToLower() && p.CompanyId == companyId);
        }

        public async Task<bool> ExistsAsync(string name, int companyId)
        {
            return await _db.ApplicationProperties
                .AnyAsync(p => p.Name!.ToLower() == name.ToLower() && p.CompanyId == companyId);
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