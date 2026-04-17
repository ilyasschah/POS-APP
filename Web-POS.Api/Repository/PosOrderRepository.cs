using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Api.Repository;

public class PosOrderRepository
{
    public readonly AppDbContext _db;

    public PosOrderRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<PosOrder>> GetAllAsync(int companyId)
    {
        return await _db.PosOrders
            .Where(p => p.CompanyId == companyId)
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.Customer)
            .ToListAsync();
    }

    public async Task<List<PosOrder>> GetAllAsync()
    {
        return await _db.PosOrders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.Customer)
            .ToListAsync();
    }

    public async Task<PosOrder?> GetByNumberAsync(string number, int companyId)
    {
        return await _db.PosOrders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.Customer)
            .FirstOrDefaultAsync(o => o.Number == number && o.CompanyId == companyId);
    }

    public async Task<PosOrder?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
    {
        var query = _db.PosOrders.AsQueryable();

        if (!trackEntity)
            query = query.AsNoTracking();

        return await query
            .Include(o => o.User)
            .Include(o => o.Customer)
            .FirstOrDefaultAsync(o => o.Id == id && o.CompanyId == companyId);
    }
    public async Task<FloorPlanTable?> GetFloorPlanTableAsync(int tableId, int companyId)
    {
        return await _db.FloorPlanTables
            .FirstOrDefaultAsync(t => t.Id == tableId && t.CompanyId == companyId);
    }
    public async Task<PosOrder?> GetByIdAsync(int id, bool trackEntity = false)
    {
        var query = _db.PosOrders.AsQueryable();

        if (!trackEntity)
            query = query.AsNoTracking();

        return await query
            .Include(o => o.User)
            .Include(o => o.Customer)
            .FirstOrDefaultAsync(o => o.Id == id);
    }

    public async Task<bool> ExistsAsync(string number)
    {
        return await _db.PosOrders.AnyAsync(o => o.Number == number);
    }

    public async Task AddAsync(PosOrder entity)
    {
        _db.PosOrders.Add(entity);
        await _db.SaveChangesAsync();
    }
    public async Task<IDbContextTransaction> BeginTransactionAsync()
    {
        return await _db.Database.BeginTransactionAsync();
    }
    public IExecutionStrategy CreateExecutionStrategy()
    {
        return _db.Database.CreateExecutionStrategy();
    }
    public async Task UpdateAsync(PosOrder entity)
    {
        _db.PosOrders.Update(entity);
        await _db.SaveChangesAsync();
    }
    public void UpdateFloorPlanTable(FloorPlanTable table)
    {
        _db.FloorPlanTables.Update(table);
    }
    public async Task DeleteAsync(PosOrder entity)
    {
        _db.PosOrders.Remove(entity);
        await _db.SaveChangesAsync();
    }
}