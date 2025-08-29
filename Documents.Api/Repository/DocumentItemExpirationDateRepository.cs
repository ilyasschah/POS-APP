using Documents.Api.DataBase;
using Documents.Api.Domain;
using Microsoft.EntityFrameworkCore;
using System.Reflection.Metadata;

namespace Documents.Api.Repository
{
    public class DocumentItemExpirationDateRepository(AppDbContext db)
    {
        public AppDbContext _db = db;
        public async Task<List<DocumentItemExpirationDate>> GetAllAsync()
        {
            return await _db.DocumentItemExpirationDates
                .ToListAsync();
        }
        public async Task<DocumentItemExpirationDate?> Getbydocumentidtoupdated(int docdocumentItemId)
        {
            return await _db.DocumentItemExpirationDates
                .AsNoTracking()
                .FirstOrDefaultAsync(dit => dit.DocumentItemId == docdocumentItemId);
        }
        public bool ExistsByDocumentItemId(int documentItemId)
        {
            return _db.DocumentItemExpirationDates
                .Any(dit => dit.DocumentItemId == documentItemId);
        }
        public async Task AddAsync(DocumentItemExpirationDate newDocumentItemexpirationdate)
        {
            _db.DocumentItemExpirationDates.Add(newDocumentItemexpirationdate);
            await _db.SaveChangesAsync();
        }
        public async Task UpdateAsync(DocumentItemExpirationDate newDocumentItemexpirationdate)
        {
            _db.DocumentItemExpirationDates.Update(newDocumentItemexpirationdate);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(DocumentItemExpirationDate documentItemexpirationdate)
        {
            _db.DocumentItemExpirationDates.Remove(documentItemexpirationdate);
            await _db.SaveChangesAsync();
        }
    }
}
