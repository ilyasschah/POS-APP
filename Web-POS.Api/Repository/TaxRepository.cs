using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class TaxRepository
    {
        private readonly AppDbContext _db;

        public TaxRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Tax>> GetAllTaxesAsync(int companyId)
        {
            return await _db.Taxes
                .Where(t => t.CompanyId == companyId)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<Tax?> GetTaxByIdAsync(int id, int companyId)
        {
            return await _db.Taxes
                .FirstOrDefaultAsync(t => t.Id == id && t.CompanyId == companyId);
        }

        public async Task<Tax?> GetByNameAsync(string name, int companyId)
        {
            return await _db.Taxes
                .FirstOrDefaultAsync(t => t.Name.ToLower() == name.ToLower() && t.CompanyId == companyId);
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

        public async Task<bool> DeleteTaxAsync(int id, int companyId)
        {
            var tax = await GetTaxByIdAsync(id, companyId);
            if (tax == null) return false;

            _db.Taxes.Remove(tax);
            return await _db.SaveChangesAsync() > 0;
        }
    }
}