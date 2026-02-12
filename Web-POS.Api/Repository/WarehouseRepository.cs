using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository
{
    public class WarehouseRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Warehouse>> GetAllWarehousesAsync(int companyId)
        {
            return await _db.Warehouses
                .Where(w => w.CompanyId == companyId)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task Add(Warehouse newWarehouse)
        {
            _db.Warehouses.Add(newWarehouse);
            await _db.SaveChangesAsync();
        }
        public bool Exists(string name, int companyId)
        {
            return _db.Warehouses.Any(w => w.Name == name);
        }
        public async Task<Warehouse?> GetwarehouseByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            return await _db.Warehouses
                .AsNoTracking()
                .FirstOrDefaultAsync(w => w.Id == id);
        }
        public async Task UpdateAsync(Warehouse warehouse)
        {
            _db.Warehouses.Update(warehouse);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(Warehouse warehouse)
        {
            _db.Warehouses.Remove(warehouse);
            await _db.SaveChangesAsync();
        }
    }
}
