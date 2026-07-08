using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class DocumentItemTaxRepository
    {
        private readonly AppDbContext _db;

        public DocumentItemTaxRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<DocumentItemTax>> GetByDocumentItemIdAsync(int documentItemId, int companyId)
        {
            return await _db.DocumentItemTaxes
                .AsNoTracking()
                .Include(dit => dit.Tax)
                .Where(dit => dit.DocumentItemId == documentItemId && dit.CompanyId == companyId)
                .ToListAsync();
        }

        /// <summary>All document-item taxes for a company (offline mirror pull).</summary>
        public async Task<List<DocumentItemTax>> GetAllByCompanyAsync(int companyId)
        {
            return await _db.DocumentItemTaxes
                .AsNoTracking()
                .Include(dit => dit.Tax)
                .Where(dit => dit.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<DocumentItemTax?> GetByIdsAsync(int documentItemId, int taxId, int companyId)
        {
            return await _db.DocumentItemTaxes
                .AsNoTracking()
                .Include(dit => dit.Tax)
                .FirstOrDefaultAsync(dit =>
                    dit.DocumentItemId == documentItemId &&
                    dit.TaxId == taxId &&
                    dit.CompanyId == companyId);
        }

        public async Task<bool> ExistsAsync(int documentItemId, int taxId, int companyId)
        {
            return await _db.DocumentItemTaxes
                .AnyAsync(dit =>
                    dit.DocumentItemId == documentItemId &&
                    dit.TaxId == taxId &&
                    dit.CompanyId == companyId);
        }

        public async Task AddAsync(DocumentItemTax newDocumentItemTax)
        {
            await _db.DocumentItemTaxes.AddAsync(newDocumentItemTax);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(DocumentItemTax documentItemTax)
        {
            _db.DocumentItemTaxes.Update(documentItemTax);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(DocumentItemTax documentItemTax)
        {
            _db.DocumentItemTaxes.Remove(documentItemTax);
            await _db.SaveChangesAsync();
        }
    }
}