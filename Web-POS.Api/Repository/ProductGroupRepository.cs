using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository
{
    public class ProductGroupRepository
    {
        private readonly AppDbContext _db;

        public ProductGroupRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<ProductGroup>> GetAllAsync(int companyId)
        {
            return await _db.ProductGroups
                .Where(p => p.CompanyId == companyId)
                .Include(p => p.ParentGroup)
                .OrderBy(p => p.Rank)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<ProductGroup?> GetByIdAsync(int id, int companyId)
        {
            return await _db.ProductGroups
                .Include(p => p.ParentGroup)
                .FirstOrDefaultAsync(p => p.Id == id && p.CompanyId == companyId);
        }
        public async Task<List<ProductGroup>> GetChildrenAsync(int parentId, int companyId)
        {
            return await _db.ProductGroups
                .Where(p => p.ParentGroupId == parentId && p.CompanyId == companyId)
                .Include(p => p.ParentGroup)
                .OrderBy(p => p.Rank)
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<bool> IsNameUniqueAsync(string name, int companyId, int? excludeId = null)
        {
            var query = _db.ProductGroups.Where(p => p.CompanyId == companyId && p.Name.ToLower() == name.ToLower());
            if (excludeId.HasValue)
            {
                query = query.Where(p => p.Id != excludeId.Value);
            }
            return !await query.AnyAsync();
        }

        public async Task AddAsync(ProductGroup entity)
        {
            _db.ProductGroups.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UpdateAsync(ProductGroup entity)
        {
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(ProductGroup entity)
        {
            try
            {
                _db.ProductGroups.Remove(entity);
                await _db.SaveChangesAsync();
                return true;
            }
            catch (DbUpdateException ex) when (ex.InnerException is Microsoft.Data.SqlClient.SqlException sqlEx && sqlEx.Number == 547)
            {
                throw new InvalidOperationException("Cannot delete this product group because it is being used by products or sub-groups.");
            }
        }
    }
}