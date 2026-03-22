using Microsoft.EntityFrameworkCore;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class PromotionItemRepository
    {
        public readonly AppDbContext _db;

        public PromotionItemRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<PromotionItem>> GetAllAsync()
        {
            return await _db.PromotionItems
                .Include(pi => pi.Promotion)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<PromotionItem?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.PromotionItems.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query
                .Include(pi => pi.Promotion)
                .FirstOrDefaultAsync(pi => pi.Id == id);
        }

        public async Task<List<PromotionItem>> GetByPromotionIdAsync(int promotionId)
        {
            return await _db.PromotionItems
                .Where(pi => pi.PromotionId == promotionId)
                .Include(pi => pi.Promotion)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task AddAsync(PromotionItem entity)
        {
            _db.PromotionItems.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(PromotionItem entity)
        {
            _db.PromotionItems.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(PromotionItem entity)
        {
            _db.PromotionItems.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}