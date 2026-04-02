using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class FloorPlanRepository
    {
        private readonly AppDbContext _db;

        public FloorPlanRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<FloorPlan>> GetAllAsync(int companyId)
        {
            return await _db.FloorPlans
                .AsNoTracking()
                .Where(f => f.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<FloorPlan?> GetByIdAsync(int id, int companyId)
        {
            return await _db.FloorPlans
                .FirstOrDefaultAsync(f => f.Id == id && f.CompanyId == companyId);
        }

        public async Task<FloorPlan> AddAsync(FloorPlan entity)
        {
            _db.FloorPlans.Add(entity);
            await _db.SaveChangesAsync();
            return entity;
        }

        public async Task<bool> UpdateAsync(FloorPlan entity)
        {
            _db.FloorPlans.Update(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(FloorPlan entity)
        {
            _db.FloorPlans.Remove(entity);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}