using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository
{
    public class FloorPlanRepository
    {
        public readonly AppDbContext _db;

        public FloorPlanRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<FloorPlan>> GetAllAsync()
        {
            return await _db.FloorPlans.AsNoTracking().ToListAsync();
        }

        public async Task<FloorPlan?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.FloorPlans.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query.FirstOrDefaultAsync(fp => fp.Id == id);
        }

        public async Task<FloorPlan?> GetByNameAsync(string name)
        {
            return await _db.FloorPlans.AsNoTracking().FirstOrDefaultAsync(fp => fp.Name == name);
        }

        public async Task<bool> ExistsAsync(string name)
        {
            return await _db.FloorPlans.AnyAsync(fp => fp.Name.ToLower() == name.ToLower());
        }

        public async Task AddAsync(FloorPlan entity)
        {
            _db.FloorPlans.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(FloorPlan entity)
        {
            _db.FloorPlans.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(FloorPlan entity)
        {
            _db.FloorPlans.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}