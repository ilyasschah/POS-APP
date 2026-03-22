using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class WarehouseRepository
    {
        private readonly AppDbContext _db;

        public WarehouseRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Warehouse>> GetAllAsync(int companyId)
        {
            return await _db.Warehouses
                .Where(w => w.CompanyId == companyId)
                .Include(w => w.Company)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<Warehouse?> GetByIdAsync(int id, int companyId)
        {
            return await _db.Warehouses
                .Include(w => w.Company)
                .FirstOrDefaultAsync(w => w.Id == id && w.CompanyId == companyId);
        }
        public async Task<Warehouse?> GetByNameAsync(string name, int companyId)
        {
            return await _db.Warehouses
                .AsNoTracking()
                .Include(w => w.Company)
                .FirstOrDefaultAsync(w => w.Name == name && w.CompanyId == companyId);
        }
        public async Task<bool> ExistsAsync(string name, int companyId)
        {
            return await _db.Warehouses
                .AnyAsync(w => w.Name.ToLower() == name.ToLower() && w.CompanyId == companyId);
        }
        public async Task AddAsync(Warehouse entity)
        {
            _db.Warehouses.Add(entity);
            await _db.SaveChangesAsync();
        }
        public async Task<bool> UpdateAsync(Warehouse warehouse)
        {
            _db.Warehouses.Update(warehouse);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var warehouse = await GetByIdAsync(id, companyId);

            if (warehouse == null)
            {
                throw new InvalidOperationException("Warehouse not found or you do not have permission to delete it.");
            }

            _db.Warehouses.Remove(warehouse);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}