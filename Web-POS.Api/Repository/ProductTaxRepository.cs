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

        public async Task<List<ProductTax>> GetAllAsync(int companyId)
        {
            return await _db.ProductsTaxes
                .AsNoTracking()
                .Where(pt => pt.CompanyId == companyId)
                .Include(pt => pt.Product)
                .Include(pt => pt.Tax)
                .ToListAsync();
        }

        public async Task<List<ProductTax>> GetByProductIdAsync(int productId, int companyId)
        {
            return await _db.ProductsTaxes
                .AsNoTracking()
                .Where(p => p.ProductId == productId && p.CompanyId == companyId)
                .Include(pt => pt.Product)
                .Include(pt => pt.Tax)
                .ToListAsync();
        }

        public async Task<List<ProductTax>> GetByTaxIdAsync(int taxId, int companyId)
        {
            return await _db.ProductsTaxes
                .AsNoTracking()
                .Where(pt => pt.TaxId == taxId && pt.CompanyId == companyId)
                .Include(pt => pt.Product)
                .Include(pt => pt.Tax)
                .ToListAsync();
        }

        public async Task<ProductTax?> FindAsync(int productId, int taxId, int companyId)
        {
            return await _db.ProductsTaxes
                .FirstOrDefaultAsync(pt => pt.ProductId == productId && pt.TaxId == taxId && pt.CompanyId == companyId);
        }

        public async Task<bool> ExistsAsync(int productId, int taxId, int companyId)
        {
            return await _db.ProductsTaxes
                .AnyAsync(pt => pt.ProductId == productId && pt.TaxId == taxId && pt.CompanyId == companyId);
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