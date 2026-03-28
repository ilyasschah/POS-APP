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

        public async Task<List<ProductComment>> GetAllAsync(int companyId)
        {
            return await _db.ProductComments
                .AsNoTracking()
                .Where(pc => pc.CompanyId == companyId)
                .Include(pc => pc.Product)
                .ToListAsync();
        }

        public async Task<ProductComment?> GetByIdAsync(int id, int companyId)
        {
            return await _db.ProductComments.AsQueryable()
                .AsNoTracking()
                .Include(pc => pc.Product)
                .FirstOrDefaultAsync(pc => pc.Id == id && pc.CompanyId == companyId);
        }

        public async Task<List<ProductComment>> GetByProductIdAsync(int productId, int companyId)
        {
            return await _db.ProductComments
                .AsNoTracking()
                .Where(pc => pc.ProductId == productId && pc.CompanyId == companyId)
                .Include(pc => pc.Product)
                .ToListAsync();
        }

        public async Task<bool> ExistsAsync(string comment, int productId, int companyId, int? excludeId = null)
        {
            var query = _db.ProductComments
                .Where(pc => pc.ProductId == productId && pc.CompanyId == companyId && pc.Comment.ToLower() == comment.ToLower());

            if (excludeId.HasValue)
            {
                query = query.Where(pc => pc.Id != excludeId.Value);
            }

            return await query.AnyAsync();
        }

        public async Task<bool> AddAsync(ProductComment entity)
        {
            _db.ProductComments.Add(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> UpdateAsync(ProductComment entity)
        {
            _db.ProductComments.Update(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(ProductComment entity)
        {
            _db.ProductComments.Remove(entity);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}
