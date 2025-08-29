using Microsoft.EntityFrameworkCore;
using Sales.Api.DataBase;
using Sales.Api.Domain;

namespace Sales.Api.Repository;

public class PosVoidRepository
{
    public readonly AppDbContext _db;

    public PosVoidRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<PosVoid>> GetAllAsync()
    {
        return await _db.PosVoids
            .AsNoTracking()
            .ToListAsync();
    }
    public async Task<PosVoid?> GetByIdAsync(int id)
    {
        return await _db.PosVoids
            .FirstOrDefaultAsync(pv => pv.Id == id);
    }
    public async Task<PosVoid?> GetByReasonAsync(string reason)
    {
        return await _db.PosVoids
            .FirstOrDefaultAsync(pv => pv.Reason == reason);
    }

    public async Task<List<PosVoid>> GetByOrderNumberAsync(string orderNumber)
    {
        return await _db.PosVoids
            .AsNoTracking()
            .Where(pv => pv.OrderNumber == orderNumber)
            .ToListAsync();
    }

    public bool Exists(string orderNumber, int roundNumber, int productId)
    {
        return _db.PosVoids.Any(pv => pv.OrderNumber == orderNumber && pv.RoundNumber == roundNumber && pv.ProductId == productId);
    }

    public async Task AddAsync(PosVoid entity)
    {
        _db.PosVoids.Add(entity);
        await _db.SaveChangesAsync();
    }

    public async Task UpdateAsync(PosVoid entity)
    {
        _db.PosVoids.Update(entity);
        await _db.SaveChangesAsync();
    }

    public async Task DeleteAsync(PosVoid entity)
    {
        _db.PosVoids.Remove(entity);
        await _db.SaveChangesAsync();
    }
}
