using Products.Api.DataBase;
using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class DocumentCategoryRepository(AppDbContext db)
    {
        public AppDbContext _db = db;
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
