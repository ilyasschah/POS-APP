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

        public async Task<PromotionItem?> GetItemByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            var query = _db.PromotionItems.AsQueryable();
            if (!trackEntity) query = query.AsNoTracking();
            return await query.FirstOrDefaultAsync(i => i.Id == id && i.CompanyId == companyId);
        }

        public async Task AddSingleItemAsync(PromotionItem item)
        {
            _db.PromotionItems.Add(item);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateSingleItemAsync(PromotionItem item)
        {
            _db.PromotionItems.Update(item);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteSingleItemAsync(PromotionItem item)
        {
            _db.PromotionItems.Remove(item);
            await _db.SaveChangesAsync();
        }
    }
}