using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Repository
{
    public class ProductCommentRepository 
    {
        private readonly AppDbContext _db;

        public ProductCommentRepository(AppDbContext db)
        {
            _db = db;
        }
        public async Task<List<ProductComment>> GetAllProductComments()
        {
            return await _db.ProductComments
                .Include(pc => pc.Product)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Product?> GetCommentByProductIdAsync(int productId)
        {
            return await _db.Products
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == productId);
        }
        public async Task Add(ProductComment newproductComment)
        {
            _db.ProductComments.Add(newproductComment);
            await _db.SaveChangesAsync();
        }
        public bool Exists(string productcomment)
        {
            return _db.ProductComments.Any(pc => pc.Comment == productcomment);
        }
        public async Task<ProductComment> UpdateProductCommentAsync(ProductComment productComment)
        {
            _db.ProductComments.Update(productComment);
            await _db.SaveChangesAsync();
            await _db.Entry(productComment)
                .Reference(pc => pc.Product)
                .LoadAsync();
            return productComment;
        }
        public async Task DeleteProductCommentAsync(ProductComment productcomment)
        {
            _db.ProductComments.Remove(productcomment);
            await _db.SaveChangesAsync();
        }
    }
}