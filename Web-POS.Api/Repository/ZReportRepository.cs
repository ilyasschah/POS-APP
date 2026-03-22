using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class ZReportRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<ZReport>> GetAllZReportAsync(int companyId)
        {
            return await _db.ZReports
                .Where(z => z.CompanyId == companyId)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<List<ZReport>> GetAllZReportAsync()
        {
            return await _db.ZReports
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<ZReport?> GetByIdAsync(int id)
        {
            return await _db.ZReports
                .AsNoTracking()
                .FirstOrDefaultAsync(dc => dc.Id == id);
        }
        public async Task Add(ZReport newZReport)
        {
            _db.ZReports.Add(newZReport);
            await _db.SaveChangesAsync();
        }
        public bool Exist(int id)
        {
            return _db.ZReports.Any(dc => dc.Id == id);
        }
        public async Task DeleteZReportAsync(ZReport ZReport)
        {
            _db.ZReports.Remove(ZReport);
            await _db.SaveChangesAsync();
        }
        
    }
}