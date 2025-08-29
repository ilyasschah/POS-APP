using Documents.Api.DataBase;
using Documents.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Documents.Api.Repository
{
    public class PaymentTypeRepository
    {
        public readonly AppDbContext _db;

        public PaymentTypeRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<PaymentType>> GetAllAsync()
        {
            return await _db.PaymentTypes.AsNoTracking().ToListAsync();
        }

        public async Task<PaymentType?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.PaymentTypes.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query.FirstOrDefaultAsync(pt => pt.Id == id);
        }

        public async Task<PaymentType?> GetByNameAsync(string name)
        {
            return await _db.PaymentTypes.AsNoTracking().FirstOrDefaultAsync(pt => pt.Name == name);
        }

        public async Task<bool> ExistsAsync(string name)
        {
            return await _db.PaymentTypes.AnyAsync(pt => pt.Name.ToLower() == name.ToLower());
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