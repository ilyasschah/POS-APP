using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class StockRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<Stock>> GetAllProducts_warehouse_StocksAsync()
        {
            return await _db.Stocks
                .AsNoTracking()
                .Include(wn => wn.Warehouse)
                .Include(pn => pn.Product)
                .ToListAsync();
        }
        public async Task Add(Stock newstock)
        {
            _db.Stocks.Add(newstock);
            await _db.SaveChangesAsync();
        }
        public async Task UpdateQuantityAsync(Stock stock)
        {
            _db.Stocks.Update(stock);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteQuantityAsync(Stock stock)
        {
            _db.Stocks.Remove(stock);
            await _db.SaveChangesAsync();
        }
        public bool Exist(int productid)
        {
            return _db.Stocks.Any(s => s.Product.Id == productid);
        }
    }
}