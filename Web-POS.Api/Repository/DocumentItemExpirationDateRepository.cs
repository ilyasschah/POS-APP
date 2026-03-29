using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class DocumentItemExpirationDateRepository
    {
        private readonly AppDbContext _db;

        public DocumentItemExpirationDateRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<DocumentItemExpirationDate?> GetByIdAsync(int documentItemId, int companyId)
        {
            return await _db.DocumentItemExpirationDates
                .FirstOrDefaultAsync(d => d.DocumentItemId == documentItemId && d.CompanyId == companyId);
        }

        public async Task<bool> ExistsAsync(int documentItemId, int companyId)
        {
            return await _db.DocumentItemExpirationDates
                .AnyAsync(d => d.DocumentItemId == documentItemId && d.CompanyId == companyId);
        }

        public async Task AddAsync(DocumentItemExpirationDate entity)
        {
            await _db.DocumentItemExpirationDates.AddAsync(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(DocumentItemExpirationDate entity)
        {
            _db.DocumentItemExpirationDates.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(DocumentItemExpirationDate entity)
        {
            _db.DocumentItemExpirationDates.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}