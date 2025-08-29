using Sales.Api.DataBase;
using Sales.Api.Domain;
using Microsoft.EntityFrameworkCore;
namespace Sales.Api.Repository;
public class PosOrderRepository 
{   
    public readonly AppDbContext _db;

    public PosOrderRepository(AppDbContext db)
    {
     _db = db;

    }
    public async Task<List<PosOrder>> GetAllAsync()
    {
        return await _db.PosOrders
        .AsNoTracking()
        .Include(o => o.User)
        .Include(o => o.Customer)
        .ToListAsync();
    
    }
    public async Task<PosOrder?> GetByNumberAsync(string number)
    {
        return await _db.PosOrders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.Customer)
            .FirstOrDefaultAsync(o => o.Number == number);
    }
    public async Task<PosOrder?> GetByIdAsync(int id, bool trackEntity = false)
    {
        return await _db.PosOrders
            .AsNoTracking()
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
    
    public async Task UpdateAsync(PosOrder entity)
    {
     _db.PosOrders.Update(entity);
        await _db.SaveChangesAsync();
    }
    
    public async Task DeleteAsync(PosOrder entity)
    {
        _db.PosOrders.Remove(entity);
       await _db.SaveChangesAsync();
    }
}