using Products.Api.DataBase;
using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class DocumentItemTaxRepository(AppDbContext db)
    {
        public AppDbContext _db = db;
        public async Task<List<DocumentItemTax>> GetByDocumentItemIdAsync(int documentItemId)
        {
            return await _db.DocumentItemTaxes
                .Where(dit => dit.DocumentItemId == documentItemId)
                .Include(dit => dit.DocumentItem)
                .Include(tax => tax.Tax)
                .ToListAsync();
        }
        public async Task<DocumentItemTax?> Getbydocumentidtoupdated(int docdocumentItemId)
        {
            return await _db.DocumentItemTaxes
                .FirstOrDefaultAsync(dit => dit.DocumentItemId == docdocumentItemId);
        }
        public bool ExistsByDocumentItemId(int documentItemId)
        {
            return _db.DocumentItemTaxes
                .Any(dit => dit.DocumentItemId == documentItemId);
        }
        public async Task AddAsync(DocumentItemTax newDocumentItemTax)
        {
            _db.DocumentItemTaxes.Add(newDocumentItemTax);
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
