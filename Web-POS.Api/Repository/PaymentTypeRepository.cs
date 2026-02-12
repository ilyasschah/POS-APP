using Products.Api.DataBase;
using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class PaymentTypeRepository
    {
        public readonly AppDbContext _db;

        public PaymentTypeRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<PaymentType>> GetAllAsync(int companyId)
        {
            return await _db.PaymentTypes
                .AsNoTracking()
                .Where(pt => pt.CompanyId == companyId)
                .ToListAsync();
        }

        public async Task<PaymentType?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            var query = _db.PaymentTypes.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query.FirstOrDefaultAsync(pt => pt.Id == id && pt.CompanyId == companyId);
        }


        public async Task<PaymentType?> GetByNameAsync(string name, int companyId)
        {
            return await _db.PaymentTypes.AsNoTracking().FirstOrDefaultAsync(pt => pt.Name == name && pt.CompanyId == companyId);
        }

        public async Task<bool> ExistsbyNameAsync(string name, int companyId)
        {
            return await _db.PaymentTypes.AnyAsync(pt => pt.Name.ToLower() == name.ToLower() && pt.CompanyId == companyId);
        }

        public async Task AddAsync(PaymentType entity)
        {
            _db.PaymentTypes.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(PaymentType entity)
        {
            _db.PaymentTypes.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(PaymentType entity)
        {
            _db.PaymentTypes.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}