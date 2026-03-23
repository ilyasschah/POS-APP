using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class DocumentTypeRepository
    {
        private readonly AppDbContext _context;

        public DocumentTypeRepository(AppDbContext context)
        {
            _context = context;
        }

        public async Task<List<DocumentType>> GetAllAsync()
        {
            return await _context.DocumentTypes
                .AsNoTracking()
                .Include(dt => dt.DocumentCategory)
                .Include(dt => dt.Warehouse)
                .ToListAsync();
        }

        public async Task<DocumentType?> GetByIdAsync(int id)
        {
            return await _context.DocumentTypes
                .AsNoTracking()
                .Include(dt => dt.DocumentCategory)
                .Include(dt => dt.Warehouse)
                .FirstOrDefaultAsync(x => x.Id == id);
        }
        public async Task AddAsync(DocumentType entity)
        {
            await _context.DocumentTypes.AddAsync(entity);
            await _context.SaveChangesAsync();
        }

        //public async Task UpdateAsync(DocumentType entity)
        //{
        //    _context.DocumentTypes.Update(entity);
        //    await _context.SaveChangesAsync();
        //}

        //public async Task DeleteAsync(DocumentType entity)
        //{
        //    _context.DocumentTypes.Remove(entity);
        //    await _context.SaveChangesAsync();
        //}
    }
}
