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

        // --- NEW LOOP PREVENTION LOGIC ---
        public async Task<bool> IsValidParentAsync(int currentGroupId, int? proposedParentId, int companyId)
        {
            // 1. Safe if it has no parent
            if (!proposedParentId.HasValue) return true;

            // 2. A group cannot be its own parent
            if (proposedParentId.Value == currentGroupId) return false;

            // 3. Walk up the tree to check if the proposed parent is actually a child of the current group
            int? currentCheckId = proposedParentId;
            while (currentCheckId.HasValue)
            {
                // Loop found! The parent we are checking is actually the group we are trying to save
                if (currentCheckId.Value == currentGroupId) return false;

                var node = await _db.ProductGroups
                    .AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Id == currentCheckId.Value && p.CompanyId == companyId);

                // Move up to the next parent in the chain
                currentCheckId = node?.ParentGroupId;
            }

            return true;
        }

        public async Task AddAsync(ProductGroup entity)
        {
            if (!await IsValidParentAsync(entity.Id, entity.ParentGroupId, entity.CompanyId))
            {
                throw new InvalidOperationException("Circular reference detected: Invalid parent folder.");
            }

            _db.ProductGroups.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UpdateAsync(ProductGroup entity)
        {
            if (!await IsValidParentAsync(entity.Id, entity.ParentGroupId, entity.CompanyId))
            {
                throw new InvalidOperationException("Action denied: You cannot place a folder inside itself, or inside one of its own sub-folders.");
            }

            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(ProductGroup entity)
        {
            // Pre-check references before deleting so we never run a DELETE that
            // SQL will reject on an FK (which EF logs as an error and spams the
            // console). Throwing up-front keeps the log clean and returns a 400.
            var inUse = await _db.Products.AnyAsync(p => p.ProductGroupId == entity.Id)
                     || await _db.ProductGroups.AnyAsync(g => g.ParentGroupId == entity.Id);
            if (inUse)
                throw new InvalidOperationException(
                    "Cannot delete this product group because it is being used by products or sub-groups.");

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