using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository;

public class PosOrderItemRepository
{
    public readonly AppDbContext _db;

    public PosOrderItemRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<PosOrderItem>> GetByPosOrderIdAsync(int posOrderId, int companyId)
    {
        return await _db.PosOrderItems
            .Where(i => i.PosOrderId == posOrderId && i.CompanyId == companyId)
            .AsNoTracking()
            .Include(i => i.Product)
            .Include(i => i.VoidedByUser)
            .ToListAsync();
    }

    public async Task<PosOrderItem?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
    {
        var query = _db.PosOrderItems.AsQueryable();

        if (!trackEntity)
            query = query.AsNoTracking();

        return await query
            .Include(i => i.Product)
            .Include(i => i.VoidedByUser)
            .FirstOrDefaultAsync(i => i.Id == id && i.CompanyId == companyId);
    }

    

    public async Task AddAsync(PosOrderItem entity)
    {
        _db.PosOrderItems.Add(entity);
        await _db.SaveChangesAsync();
    }
    public async Task AddRangeAsync(IEnumerable<PosOrderItem> entities)
    {
        await _db.PosOrderItems.AddRangeAsync(entities);
        await _db.SaveChangesAsync();
    }

    public async Task UpdateAsync(PosOrderItem entity)
    {
        _db.PosOrderItems.Update(entity);
        await _db.SaveChangesAsync();
    }

    public async Task DeleteAsync(PosOrderItem entity)
    {
        _db.PosOrderItems.Remove(entity);
        await _db.SaveChangesAsync();
    }
}