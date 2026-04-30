using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class BookingRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Booking>> GetAllAsync(int companyId)
        {
            return await _db.Bookings
                .AsNoTracking()
                .Where(b => b.CompanyId == companyId)
                .OrderBy(b => b.StartTime)
                .ToListAsync();
        }

        public async Task<Booking?> GetByIdAsync(int id, int companyId)
        {
            return await _db.Bookings
                .AsNoTracking()
                .FirstOrDefaultAsync(b => b.Id == id && b.CompanyId == companyId);
        }

        public async Task AddAsync(Booking booking)
        {
            _db.Bookings.Add(booking);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UpdateAsync(Booking booking)
        {
            _db.Bookings.Update(booking);
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(Booking booking)
        {
            _db.Bookings.Remove(booking);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}
