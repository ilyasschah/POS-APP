using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository
{
    public class DocumentItemRepository
    {
        private readonly AppDbContext _db;

        public DocumentItemRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<DocumentItem>> GetAllAsync(int companyId)
        {
            return await _db.DocumentItems
                .Where(d => d.CompanyId == companyId)
                .Include(d => d.Product)
                .Include(d => d.Document)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<DocumentItem?> GetByIdAsync(int id, int companyId)
        {
            return await _db.DocumentItems
                .Include(d => d.Product)
                .Include(d => d.Document)
                .FirstOrDefaultAsync(d => d.Id == id && d.CompanyId == companyId);
        }
        public async Task<List<DocumentItem>> GetByDocumentIdAsync(int documentId, int companyId)
        { 
            return await _db.DocumentItems
                .Where(d => d.DocumentId == documentId && d.CompanyId == companyId)
                .Include(d => d.Product)
                .Include(d => d.Document)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task AddAsync(DocumentItem entity)
        {
            _db.DocumentItems.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UpdateAsync(DocumentItem entity)
        {
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(DocumentItem entity)
        {
            _db.DocumentItems.Remove(entity);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}