using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class PaymentRepository
    {
        private readonly AppDbContext _db;

        public PaymentRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<Payment?> GetByIdAsync(int id, int companyId)
        {
            return await _db.Payments
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .FirstOrDefaultAsync(p => p.Id == id && p.CompanyId == companyId);
        }

        public async Task<IEnumerable<Payment>> GetByDocumentIdAsync(int documentId, int companyId)
        {
            return await _db.Payments
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .Where(p => p.DocumentId == documentId && p.CompanyId == companyId)
                .ToListAsync();
        }
        
        
        public async Task<IEnumerable<Payment>> GetUnreportedPaymentsAsync(int companyId)
        {
            return await _db.Payments
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .Where(p => p.CompanyId == companyId && p.ZReportId == null)
                .ToListAsync();
        }

        public async Task AddAsync(Payment payment)
        {
            await _db.Payments.AddAsync(payment);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Payment payment)
        {
            _db.Payments.Update(payment);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Payment payment)
        {
            _db.Payments.Remove(payment);
            await _db.SaveChangesAsync();
        }
    }
}