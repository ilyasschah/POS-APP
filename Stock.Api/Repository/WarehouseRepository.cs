using Microsoft.EntityFrameworkCore;
using Stocks.Api.DataBase;
using Stocks.Api.Domain;
using Stocks.Api.Models;

namespace Stocks.Api.Repository
{
    public class WarehouseRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Warehouse>> GetAllWarehousesAsync()
        {
            return await _db.Warehouses
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task Add(Warehouse newWarehouse)
        {
            _db.Warehouses.Add(newWarehouse);
            await _db.SaveChangesAsync();
        }
        public bool Exists(string name)
        {
            return _db.Warehouses.Any(w => w.Name == name);
        }
    }
}
