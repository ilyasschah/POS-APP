using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class ProductGroupRepository
    {
        private readonly AppDbContext _db;

        public ProductGroupRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<ProductGroup>> GetAllAsync()
        {
            return await _db.ProductGroups
                .AsNoTracking()
                .Include(g => g.ParentGroup)
                .Include(g => g.Children)
                .ToListAsync();
        }

        public async Task<ProductGroup?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.ProductGroups.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();

            return await q
                .Include(g => g.ParentGroup)
                .Include(g => g.Children)
                .FirstOrDefaultAsync(g => g.Id == id);
        }

        public async Task<ProductGroup?> GetByNameAsync(string name)
        {
            return await _db.ProductGroups
                .AsNoTracking()
                .Include(g => g.ParentGroup)
                .Include(g => g.Children)
                .FirstOrDefaultAsync(g => g.Name == name);
        }

        public async Task<bool> ExistsByNameAsync(string name)
        {
            return await _db.ProductGroups
                .AnyAsync(g => g.Name.ToLower() == name.ToLower());
        }

        public async Task<List<ProductGroup>> GetChildrenAsync(int parentGroupId)
        {
            return await _db.ProductGroups
                .AsNoTracking()
                .Where(g => g.ParentGroupId == parentGroupId)
                .Include(g => g.Children)
                .ToListAsync();
        }

        public async Task<List<ProductGroup>> GetRootsAsync()
        {
            return await _db.ProductGroups
                .AsNoTracking()
                .Where(g => g.ParentGroupId == null)
                .Include(g => g.Children)
                .ToListAsync();
        }

        public async Task AddAsync(ProductGroup entity)
        {
            _db.ProductGroups.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(ProductGroup entity)
        {
            _db.ProductGroups.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(ProductGroup entity)
        {
            _db.ProductGroups.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
