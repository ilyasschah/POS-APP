using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Repository
{
    public class ProductGroupRepository
    {
        public AppDbContext _db;
    
        public ProductGroupRepository(AppDbContext db) 
        {
            _db = db;
        }
        public async Task<List<ProductGroup>> GetAllProductGroupsAsync()
        {
            return await _db.ProductGroups
                .AsNoTracking()
                .Include(pg => pg.ParentGroup)
                .Include(pg => pg.ChildGroups)
                .ToListAsync();
        }
        public async Task Add(ProductGroup newproductGroup)
        {
            _db.ProductGroups.Add(newproductGroup);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteQantityAsync(ProductGroup productGroup)
        {
            _db.ProductGroups.Remove(productGroup);
            await _db.SaveChangesAsync();
        }
        public bool Exist(string Productgroupname)
        {
            return _db.ProductGroups.Any(pgn => pgn.Name == Productgroupname);
        }
    }   
}
