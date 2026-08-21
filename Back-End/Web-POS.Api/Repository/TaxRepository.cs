using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class TaxRepository
    {
        private readonly AppDbContext _db;

        public TaxRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Tax>> GetAllTaxesAsync(int companyId, DateTime? modifiedAfter = null)
        {
            var query = _db.Taxes
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

        public async Task<Tax?> GetTaxByIdAsync(int id, int companyId)
        {
            return await _db.Taxes
                .Include(w => w.Company)
                .AsQueryable()
                .FirstOrDefaultAsync(t => t.Id == id && t.CompanyId == companyId);
        }

        public async Task<Tax?> GetByNameAsync(string name, int companyId)
        {
            return await _db.Taxes
                .AsNoTracking()
                .Include(w => w.Company)
                .FirstOrDefaultAsync(t => t.Name.ToLower() == name.ToLower() && t.CompanyId == companyId);
        }
        /// <summary>
        /// Finds a tax by Code within a company. Used to pre-empt the
        /// UQ_Tax_Code_PerCompany unique index, which counts an EMPTY code as a
        /// value — so a company can only ever hold one code-less tax.
        /// Null and "" are treated as the same "no code" bucket, exactly as the
        /// index sees them once EF stores an empty string.
        /// </summary>
        public async Task<Tax?> GetByCodeAsync(string? code, int companyId)
        {
            var normalized = (code ?? string.Empty).Trim().ToLower();
            return await _db.Taxes
                .AsNoTracking()
                .FirstOrDefaultAsync(t =>
                    t.CompanyId == companyId &&
                    (t.Code ?? string.Empty).Trim().ToLower() == normalized);
        }

        public async Task<bool> ExistbyNameAsync (string name, int companyId)
        {
            return await _db.Taxes
                .Include(w => w.Company)
                .AnyAsync(t => t.Name.ToLower() == name.ToLower() && t.CompanyId == companyId);
        }
        public async Task AddTaxAsync(Tax tax)
        {
            _db.Taxes.Add(tax);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UpdateTaxAsync(Tax tax)
        {
            _db.Taxes.Update(tax);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteTaxAsync(int id, int companyId)
        {
            var tax = await GetTaxByIdAsync(id, companyId);
            if (tax == null) throw new KeyNotFoundException("Tax not found");

            _db.Taxes.Remove(tax);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}