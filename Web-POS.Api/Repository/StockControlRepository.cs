using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class StockControlRepository
    {
        private readonly AppDbContext _db;

        public StockControlRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<StockControl?> GetByIdAsync(int id, int companyId)
        {
            return await _db.StockControls
                .Include(x => x.Product)
                .Include(x => x.Customer)
                .FirstOrDefaultAsync(x => x.Id == id && x.CompanyId == companyId);
        }

        public async Task<StockControl?> GetByProductIdAsync(int productId, int companyId)
        {
            return await _db.StockControls
                .Include(x => x.Product)
                .Include(x => x.Customer)
                .FirstOrDefaultAsync(x => x.ProductId == productId && x.CompanyId == companyId);
        }

        public async Task<bool> ExistsForProductAsync(int productId, int companyId)
        {
            return await _db.StockControls
                .Include(x => x.Product)
                .Include(x => x.Customer)
                .AnyAsync(x => x.ProductId == productId && x.CompanyId == companyId);
        }

        public async Task AddAsync(StockControl entity)
        {
            await _db.StockControls.AddAsync(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(StockControl entity)
        {
            _db.StockControls.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(StockControl entity)
        {
            _db.StockControls.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}