using Microsoft.EntityFrameworkCore;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class PaymentRepository
    {
        public readonly AppDbContext _db;

        public PaymentRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Payment>> GetAllAsync(int companyId)
        {
            return await _db.Payments
                .Where(p => p.CompanyId == companyId)
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<Payment?> GetByIdAsync(int id, int companyId, bool trackEntity = false)
        {
            var query = _db.Payments.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .FirstOrDefaultAsync(p => p.Id == id && p.CompanyId == companyId);
        }

        public async Task<List<Payment>> GetByDocumentIdAsync(int documentId, int companyId)
        {
            return await _db.Payments
                .Where(p => p.DocumentId == documentId && p.CompanyId == companyId)
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .AsNoTracking()
                .ToListAsync();
        }

        // Backwards-compatible non-scoped overloads
        public async Task<List<Payment>> GetAllAsync()
        {
            return await _db.Payments
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<Payment?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.Payments.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .FirstOrDefaultAsync(p => p.Id == id);
        }

        public async Task<List<Payment>> GetByDocumentIdAsync(int documentId)
        {
            return await _db.Payments
                .Where(p => p.DocumentId == documentId)
                .Include(p => p.PaymentType)
                .Include(p => p.User)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task AddAsync(Payment entity)
        {
            _db.Payments.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Payment entity)
        {
            _db.Payments.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Payment entity)
        {
            _db.Payments.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}