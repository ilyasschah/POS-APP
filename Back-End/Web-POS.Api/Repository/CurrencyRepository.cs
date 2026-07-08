using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class CurrencyRepository
    {
        private readonly AppDbContext _db;

        public CurrencyRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Currency>> GetAllAsync()
        {
            return await _db.Currencies
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<Currency?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.Currencies.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q.FirstOrDefaultAsync(c => c.Id == id);
        }

        public async Task<Currency?> GetByNameAsync(string name)
        {
            return await _db.Currencies.AsNoTracking().FirstOrDefaultAsync(c => c.Name == name);
        }

        public async Task<bool> ExistsAsync(string name)
        {
            return await _db.Currencies.AnyAsync(c => c.Name.ToLower() == name.ToLower());
        }

        public async Task AddAsync(Currency entity)
        {
            _db.Currencies.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Currency entity)
        {
            _db.Currencies.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Currency entity)
        {
            _db.Currencies.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
