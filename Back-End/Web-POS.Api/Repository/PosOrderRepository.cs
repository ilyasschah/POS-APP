using Api.DataBase;
using Api.Domain;
using Api.Models;
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

    public async Task<List<KitchenOrderDto>> GetKitchenOrdersAsync(int companyId)
    {
        var orders = await _db.PosOrders
            .AsNoTracking()
            .Where(o => o.CompanyId == companyId && o.ServiceStatus == 2)
            .OrderBy(o => o.Id)
            .ToListAsync();

        if (orders.Count == 0) return new List<KitchenOrderDto>();

        var orderIds = orders.Select(o => o.Id).ToList();

        var tableIds = orders
            .Where(o => o.FloorPlanTableId.HasValue)
            .Select(o => o.FloorPlanTableId!.Value)
            .Distinct()
            .ToList();

        var items = await _db.PosOrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.PosOrderId) && i.CompanyId == companyId)
            .Include(i => i.Product)
            .ToListAsync();

        var tables = tableIds.Count > 0
            ? await _db.FloorPlanTables
                .AsNoTracking()
                .Where(t => tableIds.Contains(t.Id) && t.CompanyId == companyId)
                .ToListAsync()
            : new List<FloorPlanTable>();

        return orders.Select(o => new KitchenOrderDto
        {
            Id = o.Id,
            Number = o.Number,
            FloorPlanTableId = o.FloorPlanTableId,
            TableName = o.FloorPlanTableId.HasValue
                ? tables.FirstOrDefault(t => t.Id == o.FloorPlanTableId.Value)?.Name
                : null,
            ServiceType = o.ServiceType,
            ServiceStatus = o.ServiceStatus,
            DateCreated = o.DateCreated,
            Items = items
                .Where(i => i.PosOrderId == o.Id)
                .Select(i => new KitchenOrderItemDto
                {
                    Id = i.Id,
                    ProductName = i.Product?.Name ?? "Unknown",
                    Quantity = i.Quantity,
                    Comment = i.Comment,
                })
                .ToList(),
        }).ToList();
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


    /// <summary>
    /// Line-item count + newest line timestamp per order, in ONE grouped query.
    /// Lets a terminal notice that another terminal changed an order's contents
    /// without pulling every line on every 20s poll — see PosOrderDto.ItemCount.
    /// Orders with no items are simply absent from the result.
    /// </summary>
    public async Task<Dictionary<int, (int Count, DateTime? LastChanged)>> GetItemStatsAsync(
        List<int> orderIds, CancellationToken cancellationToken = default)
    {
        if (orderIds.Count == 0)
            return new Dictionary<int, (int, DateTime?)>();

        var rows = await _db.PosOrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.PosOrderId))
            .GroupBy(i => i.PosOrderId)
            .Select(g => new
            {
                PosOrderId = g.Key,
                Count = g.Count(),
                LastChanged = (DateTime?)g.Max(i => i.DateCreated)
            })
            .ToListAsync(cancellationToken);

        return rows.ToDictionary(r => r.PosOrderId, r => (r.Count, r.LastChanged));
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
    public async Task<bool> DeleteAsync(int id, int companyId)
    {
        var entity = await _db.PosOrders
            .FirstOrDefaultAsync(x => x.Id == id && x.CompanyId == companyId);

        if (entity == null)
            return false;

        _db.PosOrders.Remove(entity);
        await _db.SaveChangesAsync();

        return true;
    }
}