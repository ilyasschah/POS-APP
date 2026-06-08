using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository;

public class TimeClockRepository
{
    private readonly AppDbContext _db;

    public TimeClockRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<TimeClockEntry>> GetByCompanyIdAsync(int companyId)
    {
        return await _db.TimeClockEntries
            .AsNoTracking()
            .Where(e => e.CompanyId == companyId)
            .OrderByDescending(e => e.ClockInTime)
            .ToListAsync();
    }

    public async Task<TimeClockEntry?> GetByIdAsync(int id)
    {
        return await _db.TimeClockEntries.FirstOrDefaultAsync(e => e.Id == id);
    }

    public async Task AddAsync(TimeClockEntry entity)
    {
        _db.TimeClockEntries.Add(entity);
        await _db.SaveChangesAsync();
    }

    public async Task UpdateAsync(TimeClockEntry entity)
    {
        _db.TimeClockEntries.Update(entity);
        await _db.SaveChangesAsync();
    }
}
