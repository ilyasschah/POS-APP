// FILE: Products.Api.Repository\LoyaltyCardRepository.cs

using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository;

public class LoyaltyCardRepository
{
    public readonly AppDbContext _db;

    public LoyaltyCardRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<LoyaltyCard>> GetAllAsync()
    {
        return await _db.LoyaltyCards
            .AsNoTracking()
            .Include(lc => lc.Customer)
            .ToListAsync();
    }

    public async Task<LoyaltyCard?> GetByIdAsync(int id)
    {
        return await _db.LoyaltyCards
            .Include(lc => lc.Customer)
            .FirstOrDefaultAsync(lc => lc.Id == id);
    }

    public bool ExistsForCustomer(int customerId)
    {
        return _db.LoyaltyCards.Any(lc => lc.CustomerId == customerId);
    }

    public async Task AddAsync(LoyaltyCard entity)
    {
        _db.LoyaltyCards.Add(entity);
        await _db.SaveChangesAsync();
    }

    public async Task UpdateAsync(LoyaltyCard entity)
    {
        _db.LoyaltyCards.Update(entity);
        await _db.SaveChangesAsync();
    }

    public async Task DeleteAsync(LoyaltyCard entity)
    {
        _db.LoyaltyCards.Remove(entity);
        await _db.SaveChangesAsync();
    }
}
