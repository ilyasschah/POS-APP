using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class ProductTaxRepository
    {
        public readonly AppDbContext _db;

        public ProductTaxRepository(AppDbContext db)
        {
            _db = db;
        }
        public async Task<List<ProductTax>> GetAllAsync()
        {
            return await _db.ProductsTaxes
                .Include(pt => pt.Product)
                .Include(pt => pt.Tax)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<List<ProductTax>> GetByProductIdAsync(int productId)
        {
            return await _db.ProductsTaxes
                .Where(pt => pt.ProductId == productId)
                .Include(pt => pt.Tax)
                .AsNoTracking()
                .ToListAsync();
        }
        

        public async Task<List<ProductTax>> GetByTaxIdAsync(int taxId)
        {
            return await _db.ProductsTaxes
                .Where(pt => pt.TaxId == taxId)
                .Include(pt => pt.Product)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<ProductTax?> FindAsync(int productId, int taxId)
        {
            return await _db.ProductsTaxes.FindAsync(productId, taxId);
        }

        public async Task<bool> ExistsAsync(int productId, int taxId)
        {
            return await _db.ProductsTaxes.AnyAsync(pt => pt.ProductId == productId && pt.TaxId == taxId);
        }

        public async Task AddAsync(ProductTax entity)
        {
            _db.ProductsTaxes.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(ProductTax entity)
        {
            _db.ProductsTaxes.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}