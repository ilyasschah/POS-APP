using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class PromotionRepository
    {
        private readonly AppDbContext _db;

        public PromotionRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Promotion>> GetAllAsync(int companyId)
        {
            return await _db.Promotions
                .AsNoTracking()
                .Include(p => p.Items)
                .Where(p => p.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<List<Promotion>> GetActivePromotionsAsync(int companyId)
        {
            return await _db.Promotions
                .AsNoTracking()
                .Include(p => p.Items)
                .Where(p => p.CompanyId == companyId && p.IsEnabled)
                .ToListAsync();
        }

        public async Task<Promotion?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            var query = _db.Promotions.AsQueryable();
            if (!trackEntity) query = query.AsNoTracking();
            return await query.FirstOrDefaultAsync(p => p.Id == id && p.CompanyId == companyId);
        }

        public async Task<List<PromotionItem>> GetItemsByPromotionIdAsync(int promotionId, int companyId, bool trackEntity = false)
        {
            var query = _db.PromotionItems.Where(i => i.PromotionId == promotionId && i.CompanyId == companyId);
            if (!trackEntity) query = query.AsNoTracking();
            return await query.ToListAsync();
        }

        public async Task<List<PromotionItem>> GetItemsByPromotionIdsAsync(List<int> promotionIds, int companyId)
        {
            return await _db.PromotionItems.AsNoTracking()
                .Where(i => promotionIds.Contains(i.PromotionId) && i.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task AddPromotionAsync(Promotion promotion, List<PromotionItem> items)
        {
            _db.Promotions.Add(promotion);
            await _db.SaveChangesAsync();

            foreach (var item in items)
            {
                item.PromotionId = promotion.Id;
                _db.PromotionItems.Add(item);
            }
            await _db.SaveChangesAsync();
        }

        public async Task UpdatePromotionAsync(Promotion promotion, List<PromotionItem> newItems)
        {
            _db.Promotions.Update(promotion);

            var oldItems = await _db.PromotionItems.Where(i => i.PromotionId == promotion.Id).ToListAsync();
            _db.PromotionItems.RemoveRange(oldItems);

            foreach (var item in newItems)
            {
                item.PromotionId = promotion.Id;
                _db.PromotionItems.Add(item);
            }
            await _db.SaveChangesAsync();
        }

        public async Task DeletePromotionAsync(Promotion promotion)
        {
            var items = await _db.PromotionItems.Where(i => i.PromotionId == promotion.Id).ToListAsync();
            _db.PromotionItems.RemoveRange(items);
            _db.Promotions.Remove(promotion);
            await _db.SaveChangesAsync();
        }
    }
}