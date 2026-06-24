using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository
{
    public class DocumentCategoryRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        // Global list — document categories are shared across all companies.
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
    }
}
