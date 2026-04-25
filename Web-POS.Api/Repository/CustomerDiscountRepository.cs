using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class CustomerDiscountRepository
    {
        private readonly AppDbContext _db;

        public CustomerDiscountRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<CustomerDiscount?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            var query = _db.CustomerDiscounts.AsQueryable();
            if (!trackEntity) query = query.AsNoTracking();
            return await query.FirstOrDefaultAsync(x => x.Id == id && x.CompanyId == companyId);
        }

        public async Task<CustomerDiscount?> GetByCustomerIdAsync(int customerId, int companyId)
        {
            return await _db.CustomerDiscounts
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.CustomerId == customerId && x.CompanyId == companyId);
        }

        public async Task<List<CustomerDiscount>> GetAllAsync(int companyId)
        {
            return await _db.CustomerDiscounts
                .AsNoTracking()
                .Where(x => x.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task AddAsync(CustomerDiscount entity)
        {
            _db.CustomerDiscounts.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(CustomerDiscount entity)
        {
            _db.CustomerDiscounts.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(CustomerDiscount entity)
        {
            _db.CustomerDiscounts.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}