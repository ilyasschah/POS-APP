using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository
{
    public class DocumentCategoryRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<DocumentCategory>> GetAllAsync(int companyId)
        {
            return await _db.DocumentCategories
                .Where(dc => dc.CompanyId == companyId)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<DocumentCategory?> GetByIdAsync(int id, int companyId)
        {
            return await _db.DocumentCategories
                .AsNoTracking()
                .FirstOrDefaultAsync(dc => dc.Id == id && dc.CompanyId == companyId);
        }

        // Existing non-scoped methods for compatibility
        public async Task<List<DocumentCategory>> GetAllAsync()
        {
            return await _db.DocumentCategories
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<DocumentCategory?> GetByIdAsync(int id)
        {
            return await _db.DocumentCategories
                .AsNoTracking()
                .FirstOrDefaultAsync(dc => dc.Id == id);
        }

        public bool ExistsById(string name)
        {
            return _db.DocumentCategories.Any(dc => dc.Name == name);
        }
        public async Task AddAsync(DocumentCategory newDocumentCategory)
        {
            _db.DocumentCategories.Add(newDocumentCategory);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(DocumentCategory documentCategory)
        {
            _db.DocumentCategories.Remove(documentCategory);
            await _db.SaveChangesAsync();
        }
    }
}
