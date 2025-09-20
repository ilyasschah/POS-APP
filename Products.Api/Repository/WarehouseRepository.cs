using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository
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
