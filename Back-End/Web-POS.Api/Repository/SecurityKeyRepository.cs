using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class SecurityKeyRepository
    {
        private readonly AppDbContext _db;

        public SecurityKeyRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<SecurityKey>> GetAllAsync(int companyId)
        {
            return await _db.SecurityKeys
                .AsNoTracking()
                .Where(sk => sk.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<SecurityKey?> GetByNameAsync(string name, int companyId)
        {
            return await _db.SecurityKeys
                .FirstOrDefaultAsync(sk => sk.Name == name && sk.CompanyId == companyId);
        }

        public async Task<bool> UpdateAsync(SecurityKey entity)
        {
            _db.SecurityKeys.Update(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task AddRangeAsync(IEnumerable<SecurityKey> entities)
        {
            await _db.SecurityKeys.AddRangeAsync(entities);
            await _db.SaveChangesAsync();
        }
    }
}