using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class DocumentRepository
    {
        public readonly AppDbContext _db;

        public DocumentRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Document>> GetAllAsync(int companyId)
        {
            return await _db.Documents
                .AsNoTracking()
                .Where(d => d.CompanyId == companyId)
                .Include(d => d.User)
                .Include(d => d.Customer)
                .Include(d => d.DocumentType)
                .Include(d => d.Warehouse)
                .Include(d => d.Company)
                .ToListAsync();
        }

        public async Task<Document?> GetByIdAsync(int id, int companyId)
        {
            return await _db.Documents
                .AsNoTracking()
                .Include(d => d.User)
                .Include(d => d.Customer)
                .Include(d => d.DocumentType)
                .Include(d => d.Warehouse)
                .Include(d => d.Company)
                .FirstOrDefaultAsync(d => d.Id == id && d.CompanyId == companyId);
        }

        public async Task<Document?> GetByNumberAsync(string number, int companyId)
        {
            return await _db.Documents
                .AsNoTracking()
                .Include(d => d.User)
                .Include(d => d.Customer)
                .Include(d => d.DocumentType)
                .Include(d => d.Warehouse)
                .Include(d => d.Company)
                .FirstOrDefaultAsync(d => d.Number.ToLower() == number.ToLower() && d.CompanyId == companyId);
        }

        public async Task<bool> ExistsAsync(string number, int companyId)
        {
            return await _db.Documents
                .AnyAsync(d => d.Number.ToLower() == number.ToLower() && d.CompanyId == companyId);
        }

        public async Task<bool> AddAsync(Document entity)
        {
            _db.Documents.Add(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> UpdateAsync(Document entity)
        {
            _db.Documents.Update(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(Document entity)
        {
            _db.Documents.Remove(entity);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}