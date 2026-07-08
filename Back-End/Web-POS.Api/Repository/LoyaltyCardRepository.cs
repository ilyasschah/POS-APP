// FILE: Products.Api.Repository\LoyaltyCardRepository.cs

using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository;

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

    public async Task<List<LoyaltyCard>> GetByCompanyIdAsync(int companyId)
    {
        return await _db.LoyaltyCards
            .AsNoTracking()
            .Include(lc => lc.Customer)
            .Where(lc => lc.CompanyId == companyId)
            .ToListAsync();
    }

    public async Task<LoyaltyCard?> GetByIdAsync(int id)
    {
        return await _db.LoyaltyCards
            .Include(lc => lc.Customer)
            .FirstOrDefaultAsync(lc => lc.Id == id);
    }

    // Looks up a card by server Id first; falls back to CardNumber for cards
    // that were created offline and don't have a server Id yet.
    public async Task<LoyaltyCard?> GetByIdOrCardNumberAsync(int? id, string? cardNumber)
    {
        if (id.HasValue && id > 0)
            return await _db.LoyaltyCards.FirstOrDefaultAsync(lc => lc.Id == id.Value);

        if (!string.IsNullOrWhiteSpace(cardNumber))
            return await _db.LoyaltyCards.FirstOrDefaultAsync(lc => lc.CardNumber == cardNumber);

        return null;
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
