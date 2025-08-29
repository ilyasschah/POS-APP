using Documents.Api.DataBase;
using Documents.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Documents.Api.Repository
{
    public class DocumentCategoryRepository(AppDbContext db)
    {
        public AppDbContext _db = db;
        public async Task<List<Domain.DocumentCategory>> GetAllAsync()
        {
            return await _db.DocumentCategories
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Domain.DocumentCategory?> GetByIdAsync(int id)
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
