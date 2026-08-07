using Api.DataBase;
using Api.Domain;
using Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Api.Repository
{
    public class UserDevicePinRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<UserDevicePin?> GetByUserAndDeviceAsync(int userId, string deviceId, int companyId, CancellationToken cancellationToken = default)
        {
            return await _db.UserDevicePins
                .FirstOrDefaultAsync(p => p.UserId == userId && p.DeviceId == deviceId && p.CompanyId == companyId, cancellationToken);
        }

        /// <summary>
        /// Every user's PIN row on one terminal. Revoking removes the terminal
        /// from the ACCOUNT, not from one cashier, so all of them are cleared —
        /// otherwise the device stays listed under every other user who had a PIN
        /// on it, pointing at a registry row that no longer exists.
        /// </summary>
        public async Task<List<UserDevicePin>> GetByDeviceAsync(string deviceId, int companyId, CancellationToken cancellationToken = default)
        {
            return await _db.UserDevicePins
                .Where(p => p.DeviceId == deviceId && p.CompanyId == companyId)
                .ToListAsync(cancellationToken);
        }

        public async Task SaveChangesAsync(CancellationToken cancellationToken = default)
            => await _db.SaveChangesAsync(cancellationToken);
        public async Task<List<UserDevicePinDto>> GetActiveDevicesAsync(int? userId,int companyId, CancellationToken cancellationToken = default)
        {
            // Exclude revoked devices. RevokeDevicePinAsync blanks the HashedPin
            // (it doesn't delete the row), so a revoked device must be filtered
            // out here or it keeps showing as "active".
            var query = _db.UserDevicePins.Where(p =>
                p.CompanyId == companyId &&
                p.HashedPin != null && p.HashedPin != "");

            if (userId.HasValue && userId > 0)
            {
                query = query.Where(p => p.UserId == userId.Value);
            }

            return await query
                .AsNoTracking()
                .Join(_db.Users,
                    pin => pin.UserId,
                    user => user.Id,
                    (pin, user) => new UserDevicePinDto
                    {
                        DeviceId = pin.DeviceId,
                        CreatedAt = pin.CreatedAt,
                        UserId = user.Id,
                        Username = user.Username,
                        UserDisplayName = user.FirstName + " " + user.LastName
                    })
                .ToListAsync(cancellationToken);
        }
        public async Task AddAsync(UserDevicePin entity, CancellationToken cancellationToken = default)
        {
            _db.UserDevicePins.Add(entity);
            await _db.SaveChangesAsync(cancellationToken);
        }

        public async Task UpdateAsync(UserDevicePin entity, CancellationToken cancellationToken = default)
        {
            _db.UserDevicePins.Update(entity);
            await _db.SaveChangesAsync(cancellationToken);
        }
        
        public async Task RemoveAsync(UserDevicePin entity, CancellationToken cancellationToken = default)
        {
            _db.UserDevicePins.Remove(entity);
            await _db.SaveChangesAsync(cancellationToken);
        }
    }
}