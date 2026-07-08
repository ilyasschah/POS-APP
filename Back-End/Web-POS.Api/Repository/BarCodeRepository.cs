using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class BarcodeRepository
    {
        private readonly AppDbContext _db;

        public BarcodeRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Barcode>> GetProductsNamesBarcodesAsync(int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Include(b => b.Product)
                .Where(b => b.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<Barcode?> GetBarCodeByIdQuery(int id, int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Include(b => b.Product)
                .FirstOrDefaultAsync(b => b.Id == id && b.CompanyId == companyId);
        }

        public async Task<Barcode?> GetByValueAsync(string value, int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Include(b => b.Product)
                .FirstOrDefaultAsync(b => b.Value == value && b.CompanyId == companyId);
        }

        public async Task<List<Barcode>> GetByProductIdAsync(int productId, int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Include(b => b.Product)
                .Where(b => b.ProductId == productId && b.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<bool> ExistsByValueAsync(string value, int companyId)
        {
            return await _db.Barcodes
                .AnyAsync(c => c.Value == value && c.CompanyId == companyId);
        }

        public async Task AddAsync(Barcode newBarcode)
        {
            await _db.Barcodes.AddAsync(newBarcode);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Barcode barcode)
        {
            _db.Barcodes.Update(barcode);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Barcode barcode)
        {
            _db.Barcodes.Remove(barcode);
            await _db.SaveChangesAsync();
        }
    }
}