using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Repository
{
    public class TaxRepository
    {
        private readonly AppDbContext _db;
        public TaxRepository(AppDbContext db)
        {
            _db = db;
        }
        public async Task<List<Tax>> GetAllTaxesAsync()
        {
            return await _db.Taxes
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Tax?> GetTaxByIdAsync(int id)
        {
            return await _db.Taxes.FindAsync(id);
        }
        public async Task AddTaxAsync(Tax tax)
        {
            _db.Taxes.Add(tax);
            await _db.SaveChangesAsync();
        }
        public async Task<bool> UpdateTaxAsync(Tax tax)
        {
            _db.Taxes.Update(tax);
            return await _db.SaveChangesAsync() > 0;
        }
        public async Task<bool> DeleteTaxAsync(int id)
        {
            var tax = await GetTaxByIdAsync(id);
            if (tax == null) return false;
            _db.Taxes.Remove(tax);
            return await _db.SaveChangesAsync() > 0;
        }
    }
}
