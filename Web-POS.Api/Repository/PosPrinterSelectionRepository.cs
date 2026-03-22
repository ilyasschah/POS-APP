using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class PosPrinterSelectionRepository
    {
        private readonly AppDbContext _db;

        public PosPrinterSelectionRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<PosPrinterSelection>> GetAllAsync()
        {
            return await _db.PosPrinterSelections.AsNoTracking().ToListAsync();
        }

        public async Task<PosPrinterSelection?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.PosPrinterSelections.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q.FirstOrDefaultAsync(p => p.Id == id);
        }

        public async Task<PosPrinterSelection?> GetByKeyAsync(string key)
        {
            return await _db.PosPrinterSelections.AsNoTracking()
                .FirstOrDefaultAsync(p => p.Key == key);
        }

        public async Task<bool> ExistsAsync(string key)
        {
            return await _db.PosPrinterSelections.AnyAsync(p => p.Key.ToLower() == key.ToLower());
        }

        public async Task AddAsync(PosPrinterSelection entity)
        {
            _db.PosPrinterSelections.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(PosPrinterSelection entity)
        {
            _db.PosPrinterSelections.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(PosPrinterSelection entity)
        {
            _db.PosPrinterSelections.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
