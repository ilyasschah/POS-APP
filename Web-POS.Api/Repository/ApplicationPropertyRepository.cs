using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class ApplicationPropertyRepository
    {
        private readonly AppDbContext _db;

        public ApplicationPropertyRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<ApplicationProperty>> GetAllAsync()
        {
            return await _db.ApplicationProperties
                .AsNoTracking()
                .OrderBy(p => p.Name)
                .ToListAsync();
        }

        public async Task<ApplicationProperty?> GetByNameAsync(string name, bool trackEntity = false)
        {
            var q = _db.ApplicationProperties.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q.FirstOrDefaultAsync(p => p.Name == name);
        }

        public async Task<bool> ExistsAsync(string name)
        {
            return await _db.ApplicationProperties.AnyAsync(p => p.Name.ToLower() == name.ToLower());
        }

        public async Task AddAsync(ApplicationProperty entity)
        {
            _db.ApplicationProperties.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(ApplicationProperty entity, string originalName)
        {
            // handle potential rename of PK (Name)
            var tracked = await _db.ApplicationProperties.FirstOrDefaultAsync(p => p.Name == originalName);
            if (tracked == null) return;
            tracked.Name = entity.Name;
            tracked.Value = entity.Value;
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(ApplicationProperty entity)
        {
            _db.ApplicationProperties.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
