using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class ProductRepository
    {
        private readonly AppDbContext _db;

        public ProductRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Product>> GetAllAsync(int companyId)
        {
            return await _db.Products
                .AsNoTracking()
                .Where(p => p.CompanyId == companyId)
                .Include(p => p.ProductGroup)
                .Include(p => p.Currency)
                .ToListAsync();
        }
        public async Task<Product?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            var q = _db.Products.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q
                .Include(p => p.ProductGroup)
                .Include(p => p.Currency)
                .FirstOrDefaultAsync(p => p.Id == id && p.CompanyId == companyId);
        }

        public async Task<Product?> GetByProductGroupAsync(int productGroupId, int companyId)
        {
            return await _db.Products
                .AsNoTracking()
                .Include(p => p.ProductGroup)
                .FirstOrDefaultAsync(p => p.ProductGroupId == productGroupId && p.CompanyId == companyId);
        }
        public async Task<Product?> GetByCodeAsync(string code, int companyId)
        {
            return await _db.Products
                .AsNoTracking()
                .Include(p => p.ProductGroup)
                .Include(p => p.Currency)
                .FirstOrDefaultAsync(p => p.Code == code && p.CompanyId == companyId);
        }

        public async Task<bool> ExistsByNameAsync(string name, int companyId)
        {
            return await _db.Products.AnyAsync(p => p.Name == name && p.CompanyId == companyId);
        }

        public async Task<bool> ExistsByCodeAsync(string code, int companyId)
        {
            return await _db.Products.AnyAsync(p => p.Code == code && p.CompanyId == companyId);
        }

        public async Task AddAsync(Product entity)
        {
            _db.Products.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Product entity)
        {
            _db.Products.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Product entity)
        {
            _db.Products.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
