using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Domain;

namespace Api.Repository
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
                .Include(w => w.Company)
                .ToListAsync();
        }

        public async Task<PaymentType?> GetByIdAsync(int id, int companyId)
        {
            return await _db.PaymentTypes
                .Include(w => w.Company)
                .AsQueryable()
                .FirstOrDefaultAsync(pt => pt.Id == id && pt.CompanyId == companyId);
        }


        public async Task<PaymentType?> GetByNameAsync(string name, int companyId)
        {
            return await _db.PaymentTypes
                .AsNoTracking()
                .Include(w => w.Company)
                .FirstOrDefaultAsync(pt => pt.Name == name && pt.CompanyId == companyId);
        }

        public async Task<bool> ExistsbyNameAsync(string name, int companyId)
        {
            return await _db.PaymentTypes
                .Include(w => w.Company)
                .AnyAsync(pt => pt.Name.ToLower() == name.ToLower() && pt.CompanyId == companyId);
        }

        public async Task AddAsync(PaymentType entity)
        {
            _db.PaymentTypes.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UpdateAsync(PaymentType entity)
        {
            _db.PaymentTypes.Update(entity);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await GetByIdAsync(id, companyId);
            if (entity == null)
                throw new InvalidOperationException("Payment type not found or you do not have permission to delete it.");

            bool usedInPayments = await _db.Payments.AnyAsync(p => p.PaymentTypeId == id);
            bool usedInZReports = await _db.ZReportPaymentSummaries.AnyAsync(z => z.PaymentTypeId == id);
            if (usedInPayments || usedInZReports)
                throw new InvalidOperationException("This payment type cannot be deleted because it is already used in transactions or Z-reports.");

            _db.PaymentTypes.Remove(entity);
            try
            {
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                // Defensive net: a foreign-key constraint (e.g. another table that
                // still references this payment type) turns into a friendly 400
                // instead of an unhandled 500.
                throw new InvalidOperationException("This payment type cannot be deleted because it is still referenced by existing records.");
            }
            return true;
        }
    }
}