using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository;

public class ShiftRepository
{
    private readonly AppDbContext _db;

    public ShiftRepository(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<Shift>> GetByCompanyIdAsync(int companyId)
    {
        return await _db.Shifts
            .AsNoTracking()
            .Where(s => s.CompanyId == companyId)
            .OrderByDescending(s => s.OpenedAt)
            .ToListAsync();
    }

    public async Task<Shift?> GetByIdAsync(int id)
    {
        return await _db.Shifts.FirstOrDefaultAsync(s => s.Id == id);
    }

    public async Task<Shift?> GetOpenShiftAsync(int companyId)
    {
        return await _db.Shifts
            .FirstOrDefaultAsync(s => s.CompanyId == companyId && s.Status == 0);
    }

    public async Task AddAsync(Shift entity)
    {
        _db.Shifts.Add(entity);
        await _db.SaveChangesAsync();
    }

    public async Task UpdateAsync(Shift entity)
    {
        _db.Shifts.Update(entity);
        await _db.SaveChangesAsync();
    }
}
