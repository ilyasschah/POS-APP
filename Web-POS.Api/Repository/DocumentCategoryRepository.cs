using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository
{
    public class DocumentCategoryRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

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
                .Where(dc => dc.CompanyId == companyId)
                .AsNoTracking()
                .FirstOrDefaultAsync(dc => dc.Id == id && dc.CompanyId == companyId);
        }


        public async Task<bool> ExistsByName(string name, int companyId)
        {
            return await _db.DocumentCategories
                .AnyAsync(dc => dc.Name == name && dc.CompanyId == companyId);
        }
        public async Task<bool> AddAsync(DocumentCategory newDocumentCategory)
        {
            _db.DocumentCategories.Add(newDocumentCategory);
            await _db.SaveChangesAsync();
            return true;
        }
        public async Task<bool> DeleteAsync(DocumentCategory documentCategory)
        {
            _db.DocumentCategories.Remove(documentCategory);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}
