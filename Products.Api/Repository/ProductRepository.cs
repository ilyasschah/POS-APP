using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;
using Products.Api.Models;
namespace Products.Api.Repository
{
    public class ProductRepository
    {
        public AppDbContext _db;

        public ProductRepository(AppDbContext db)
        {
            _db = db;
        }
        public async Task<List<Product>> GetProducts()
        {
            return await _db.Products
                .AsNoTracking()
                .Include(g => g.ProductGroup)
                .Include(pg =>pg.ProductGroup.ParentGroup)
                .Include(c => c.Currency)
                .ToListAsync();
        }
        
        //public async Task<Product?> GetProductByIdAsync(int id)
        //{
        //    return await _db.Products
        //        .AsNoTracking()
        //        .Include(p => p.ProductGroup)
        //        .ThenInclude(pg => pg.ParentGroup)
        //        .Include(p => p.Currency)
        //        .FirstOrDefaultAsync(pr => pr.Id == id);
        //}
        public async Task<List<Product>> GetProductByName(string Name)
        {
            return await _db.Products
                .AsNoTracking()
                .Where(pr => pr.Name.Contains(Name))
                .ToListAsync();
        }
        public async Task<decimal> GetTotalPrice(string name)
        {
            return await _db.Products
                .AsNoTracking()
                .Where(pr => pr.Name.Contains(name))
                .SumAsync(pr => pr.Price);
        }
        public async Task Add(Product newproduct)
        {
            _db.Products.Add(newproduct);
            await _db.SaveChangesAsync();
        }
        public bool Exist(string productname)
        {
            return _db.Products.Any(p => p.Name == productname);
        }
        //public async Task<Product> UpdateProductAsync(Product product)
        //{
        //    if (product == null)
        //        throw new ArgumentNullException(nameof(product));
        //    _db.Products.Update(product);
        //    await _db.SaveChangesAsync();
        //    return product;
        //}
        public async Task DeleteProductAsync(Product product)
        {
            _db.Products.Remove(product);
            await _db.SaveChangesAsync();
        }
    }
}
