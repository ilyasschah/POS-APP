using Microsoft.EntityFrameworkCore;
using System.Collections.Generic;
using System.Threading.Tasks;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class FiscalItemRepository
    {
        public readonly AppDbContext _db;

        public FiscalItemRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<FiscalItem>> GetAllAsync()
        {
            return await _db.FiscalItems.AsNoTracking().ToListAsync();
        }

        public async Task<FiscalItem?> GetByPluAsync(int plu, bool trackEntity = false)
        {
            var query = _db.FiscalItems.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query.FirstOrDefaultAsync(fi => fi.PLU == plu);
        }

        public async Task<bool> ExistsAsync(int plu)
        {
            return await _db.FiscalItems.AnyAsync(fi => fi.PLU == plu);
        }

        public async Task AddAsync(FiscalItem entity)
        {
            _db.FiscalItems.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(FiscalItem entity)
        {
            _db.FiscalItems.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(FiscalItem entity)
        {
            _db.FiscalItems.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}