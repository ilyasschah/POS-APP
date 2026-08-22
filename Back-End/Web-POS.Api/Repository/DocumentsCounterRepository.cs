using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class DocumentsCounterRepository
    {
        public readonly AppDbContext _db;

        public DocumentsCounterRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<DocumentsCounter>> GetAllAsync()
        {
            return await _db.DocumentsCounter
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<DocumentsCounter?> GetByNameAsync(string name, bool trackEntity = false)
        {
            var query = _db.DocumentsCounter.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query.FirstOrDefaultAsync(c => c.Name!.ToLower() == name.ToLower());
        }

        public async Task<bool> ExistsAsync(string name)
        {
            return await _db.DocumentsCounter.AnyAsync(c => c.Name!.ToLower() == name.ToLower());
        }

        public async Task AddAsync(DocumentsCounter entity)
        {
            _db.DocumentsCounter.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(DocumentsCounter entity)
        {
            _db.DocumentsCounter.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(DocumentsCounter entity)
        {
            _db.DocumentsCounter.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}