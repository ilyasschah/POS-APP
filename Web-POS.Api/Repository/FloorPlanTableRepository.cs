using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class FloorPlanTableRepository
    {
        private readonly AppDbContext _db;

        public FloorPlanTableRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<FloorPlanTable>> GetAllAsync(int companyId)
        {
            return await _db.FloorPlanTables
                .AsNoTracking()
                .Where(t => t.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<List<FloorPlanTable>> GetByFloorPlanIdAsync(int floorPlanId, int companyId)
        {
            return await _db.FloorPlanTables
                .AsNoTracking()
                .Where(t => t.FloorPlanId == floorPlanId && t.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<FloorPlanTable?> GetByIdAsync(int id, int companyId)
        {
            return await _db.FloorPlanTables
                .FirstOrDefaultAsync(t => t.Id == id && t.CompanyId == companyId);
        }

        public async Task<FloorPlanTable?> GetByNameAsync(string name, int companyId)
        {
            return await _db.FloorPlanTables
                .FirstOrDefaultAsync(t => t.Name == name && t.CompanyId == companyId);
        }

        public async Task<FloorPlanTable> AddAsync(FloorPlanTable entity)
        {
            _db.FloorPlanTables.Add(entity);
            await _db.SaveChangesAsync();
            return entity;
        }

        public async Task<bool> UpdateAsync(FloorPlanTable entity)
        {
            _db.FloorPlanTables.Update(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(FloorPlanTable entity)
        {
            _db.FloorPlanTables.Remove(entity);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}