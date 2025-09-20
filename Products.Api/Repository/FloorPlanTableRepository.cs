using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class FloorPlanTableRepository
    {
        public readonly AppDbContext _db;

        public FloorPlanTableRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<FloorPlanTable>> GetAllAsync()
        {
            return await _db.FloorPlanTables
                .Include(fpt => fpt.FloorPlan)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<FloorPlanTable?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.FloorPlanTables.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query
                .Include(fpt => fpt.FloorPlan)
                .FirstOrDefaultAsync(fpt => fpt.Id == id);
        }
        public async Task<FloorPlanTable?> GetByNameAsync(string name)
        {
            return await _db.FloorPlanTables
                .AsNoTracking()
                .Include(fpt => fpt.FloorPlan)
                .FirstOrDefaultAsync(fpt => fpt.Name.ToLower() == name.ToLower());
        }
        public async Task<List<FloorPlanTable>> GetByFloorPlanIdAsync(int floorPlanId)
        {
            return await _db.FloorPlanTables
                .Where(fpt => fpt.FloorPlanId == floorPlanId)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<bool> ExistsAsync(string name, int floorPlanId)
        {
            return await _db.FloorPlanTables.AnyAsync(fpt => fpt.Name.ToLower() == name.ToLower() && fpt.FloorPlanId == floorPlanId);
        }

        public async Task AddAsync(FloorPlanTable entity)
        {
            _db.FloorPlanTables.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(FloorPlanTable entity)
        {
            _db.FloorPlanTables.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(FloorPlanTable entity)
        {
            _db.FloorPlanTables.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}