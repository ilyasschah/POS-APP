using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class StockRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<Stock>> GetAllProducts_warehouse_StocksAsync(int companyId)
        {
            return await _db.Stocks
                .AsNoTracking()
                .Where(s => s.CompanyId == companyId)
                .Include(wn => wn.Warehouse)
                .Include(pn => pn.Product)
                .ToListAsync();
        }
        public async Task<Stock?> GetStockByIdQuery(int id, int companyId)
        {
            return await _db.Stocks
            .AsNoTracking()
            .Where(s => s.CompanyId == companyId)
            .Include(s => s.Product)
            .Include(s => s.Warehouse)
            .FirstOrDefaultAsync(s => s.Id == id && s.CompanyId == companyId);
        }
        public async Task Add(Stock newstock)
        {
            _db.Stocks.Add(newstock);
            await _db.SaveChangesAsync();
        }
        public bool Existby_P_id_W_id(int productid, int warehouseid, int companyid)
        {
            return _db.Stocks.Any(s => s.Product.Id == productid && s.Warehouse.Id == warehouseid && s.CompanyId == companyid);
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
        
    }
}