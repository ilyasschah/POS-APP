using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class ZReportRepository
    {
        private readonly AppDbContext _db;

        public ZReportRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<ZReport?> GetByIdAsync(int id, int companyId)
        {
            return await _db.ZReports
                .Include(z => z.PaymentSummaries)
                    .ThenInclude(ps => ps.PaymentType) 
                .FirstOrDefaultAsync(z => z.Id == id && z.CompanyId == companyId);
        }

        public async Task<IEnumerable<ZReport>> GetAllAsync(int companyId)
        {
            return await _db.ZReports
                .Include(z => z.PaymentSummaries)
                    .ThenInclude(ps => ps.PaymentType)
                .Where(z => z.CompanyId == companyId)
                .OrderByDescending(z => z.DateCreated) 
                .ToListAsync();
        }

        public async Task<ZReport?> GetLastZReportAsync(int companyId)
        {
            return await _db.ZReports
                .Where(z => z.CompanyId == companyId)
                .OrderByDescending(z => z.Id)
                .FirstOrDefaultAsync();
        }

        public async Task AddAsync(ZReport zReport)
        {
            await _db.ZReports.AddAsync(zReport);
            await _db.SaveChangesAsync();
        }

    }
}