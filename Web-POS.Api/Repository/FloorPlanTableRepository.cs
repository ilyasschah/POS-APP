using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;
using Api.Models;

namespace Api.Repository
{
    public class FloorPlanTableRepository
    {
        private readonly AppDbContext _db;

        public FloorPlanTableRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<FloorPlanTable>> GetAllAsync(int companyId, DateTime? modifiedAfter = null)
        {
            var query = _db.FloorPlanTables
                .AsNoTracking()
                .Where(t => t.CompanyId == companyId);

            if (modifiedAfter.HasValue)
            {
                var watermark = modifiedAfter.Value.Kind == DateTimeKind.Utc
                    ? modifiedAfter.Value
                    : modifiedAfter.Value.ToUniversalTime();
                query = query.Where(t => t.LastModified > watermark);
            }

            return await query.ToListAsync();
        }

        public async Task<List<FloorPlanTableDto>> GetByFloorPlanIdAsync(int floorPlanId, int companyId)
        {
            return await _db.FloorPlanTables
                .AsNoTracking()
                .Where(t => t.FloorPlanId == floorPlanId && t.CompanyId == companyId)
                .Select(t => new FloorPlanTableDto
                {
                    Id = t.Id,
                    FloorPlanId = t.FloorPlanId,
                    Name = t.Name,
                    Status = t.Status,
                    PositionX = t.PositionX,
                    PositionY = t.PositionY,
                    Width = t.Width,
                    Height = t.Height,
                    IsRound = t.IsRound,
                    AssignedUserId = _db.PosOrders
                        .Where(o => o.FloorPlanTableId == t.Id && o.CompanyId == companyId)
                        .OrderByDescending(o => o.Id)
                        .Select(o => (int?)o.UserId)
                        .FirstOrDefault()
                })
                .ToListAsync();
        }

        public async Task<FloorPlanTable?> GetByIdAsync(int id, int companyId)
        {
            return await _db.FloorPlanTables
                .AsNoTracking()
                .FirstOrDefaultAsync(t => t.Id == id && t.CompanyId == companyId);
        }

        public async Task<FloorPlanTable?> GetByNameAsync(string name, int companyId)
        {
            return await _db.FloorPlanTables
                .AsNoTracking()
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