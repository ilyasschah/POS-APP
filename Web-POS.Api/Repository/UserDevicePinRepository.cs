using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class UserDevicePinRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<UserDevicePin?> GetByUserAndDeviceAsync(int userId, string deviceId)
        {
            return await _db.UserDevicePins
                .FirstOrDefaultAsync(p => p.UserId == userId && p.DeviceId == deviceId);
        }

        public async Task AddAsync(UserDevicePin entity)
        {
            _db.UserDevicePins.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(UserDevicePin entity)
        {
            _db.UserDevicePins.Update(entity);
            await _db.SaveChangesAsync();
        }
    }
}