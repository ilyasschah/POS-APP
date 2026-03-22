using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class ProductCommentRepository
    {
        private readonly AppDbContext _db;

        public ProductCommentRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<ProductComment>> GetAllAsync()
        {
            return await _db.ProductComments
                .AsNoTracking()
                .Include(pc => pc.Product)
                .ToListAsync();
        }

        public async Task<ProductComment?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.ProductComments.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();

            return await q
                .Include(pc => pc.Product)
                .FirstOrDefaultAsync(pc => pc.Id == id);
        }

        public async Task<List<ProductComment>> GetByProductIdAsync(int productId)
        {
            return await _db.ProductComments
                .AsNoTracking()
                .Where(pc => pc.ProductId == productId)
                .Include(pc => pc.Product)
                .ToListAsync();
        }

        public async Task<bool> ProductExistsAsync(int productId)
        {
            return await _db.Products.AnyAsync(p => p.Id == productId);
        }

        public async Task AddAsync(ProductComment entity)
        {
            _db.ProductComments.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(ProductComment entity)
        {
            _db.ProductComments.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(ProductComment entity)
        {
            _db.ProductComments.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
