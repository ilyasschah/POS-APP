using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class BarcodeRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Barcode>> GetProductsNamesBarcodesAsync(int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Where(b => b.CompanyId == companyId)
                .Include(BarCode => BarCode.Product)
                .Include(BarCode => BarCode.Company)
                .ToListAsync();
        }
        public async Task<Barcode?> GetBarCodeByIdQuery(int id, int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Where(s => s.CompanyId == companyId)
                .Include(b => b.Product)
                .Include(b => b.Company)
                .FirstOrDefaultAsync(b => b.Id == id && b.CompanyId == companyId);
        }
        public async Task<Barcode?> GetByValueAsync(string value, int companyId)
        {
            return await _db.Barcodes
                .AsNoTracking()
                .Where(s => s.CompanyId == companyId) 
                .Include(b => b.Product)
                .Include(b => b.Company)
                .FirstOrDefaultAsync(b => b.Value == value && b.CompanyId == companyId);
        }
        public bool Existsbyvalue(string value, int companyId)
        {
            return _db.Barcodes
                .Where(c => c.CompanyId == companyId)
                .Any(c => c.Value == value && c.CompanyId == companyId);
        }
        public async Task Add(Barcode newBarcode)
        {
            _db.Barcodes.Add(newBarcode);
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
