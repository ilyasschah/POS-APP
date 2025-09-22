using Products.Api.DataBase;
using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class DocumentItemRepository(AppDbContext db)
    {
        public AppDbContext _db = db;
        public async Task<List<DocumentItem>> GetDocumentItemsAsync()
        {
            return await _db.DocumentItems
                .AsNoTracking()
                .Include(Document => Document.Document)
                .Include(Product => Product.Product)
                .ToListAsync();
        }
        public async Task<List<DocumentItem>> GetDocumentItemsByDocumentIdAsync(int documentId)
        {
            return await _db.DocumentItems
                .Where(di => di.DocumentId == documentId)
                .Include(Document => Document.Document)
                .Include(Product => Product.Product)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<DocumentItem?> GetDocumentItemByIdAsync(int id)
        {
            return await _db.DocumentItems
                .AsNoTracking()
                .Include(Document => Document.Document)
                .Include(Product => Product.Product)
                .FirstOrDefaultAsync(di => di.Id == id);
        }
        //public bool ExistsById(int documentid)
        //{
        //    return _db.DocumentItems
        //        .Any(di => di.DocumentId == documentid);
        //}
        public async Task Add(DocumentItem newDocumentItem)
        {
            _db.DocumentItems.Add(newDocumentItem);
            await _db.SaveChangesAsync();
        }
        public async Task UpdateAsync(DocumentItem documentItem)
        {
            _db.DocumentItems.Update(documentItem);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(DocumentItem documentItem)
        {
            _db.DocumentItems.Remove(documentItem);
            await _db.SaveChangesAsync();
        }
    }
}
