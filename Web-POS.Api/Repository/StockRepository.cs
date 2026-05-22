using Microsoft.EntityFrameworkCore;
using System.ComponentModel.Design;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class StockRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<Stock>> GetAllStocksAsync(int companyId)
        {
            return await _db.Stocks
                .Where(s => s.CompanyId == companyId)
                .Include(s => s.Warehouse)
                .Include(s => s.Product)
                .Include(s => s.Company)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Stock?> GetStockByIdAsync(int id, int companyId)
        {
            return await _db.Stocks
                .Where(s => s.CompanyId == companyId)
                .Include(s => s.Warehouse)
                .Include(s => s.Product)
                .Include(s => s.Company)
                .FirstOrDefaultAsync(s => s.Id == id && s.CompanyId == companyId);
        }

        public async Task<bool> Existby_P_id_W_id(int productid, int warehouseid, int companyid)
        {
            return await _db.Stocks
                .AnyAsync(s => s.ProductId == productid && s.WarehouseId == warehouseid && s.CompanyId == companyid);
        }

        public async Task<Stock?> GetByProductAndWarehouseAsync(int productId, int warehouseId, int companyId)
        {
            return await _db.Stocks
                .FirstOrDefaultAsync(s => s.ProductId == productId && s.WarehouseId == warehouseId && s.CompanyId == companyId);
        }
        public async Task Add(Stock newstock)
        {
            _db.Stocks.Add(newstock);
            await _db.SaveChangesAsync();
        }
        public async Task<bool> UpdateQuantityAsync(Stock entity)
        {
            await _db.SaveChangesAsync();
            return true;
        }
        public async Task<bool> DeleteQuantityAsync(int id , int companyId)
        {
            var entity = await GetStockByIdAsync(id, companyId);
            if (entity == null)
            {
                throw new KeyNotFoundException($"Stock with id {id} not found for company {companyId}");
            }
            _db.Stocks.Remove(entity);
            await _db.SaveChangesAsync();
            return true;
        }
        
    }
}