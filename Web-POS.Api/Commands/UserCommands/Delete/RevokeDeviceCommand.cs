using MediatR;
using Api.DataBase;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.UserCommands.Delete;

public class RevokeDeviceCommand : IRequest<bool>
{
    public int UserId { get; set; }
    public int CompanyId { get; set; }
    public string DeviceId { get; set; } = string.Empty;

    public class RevokeDeviceCommandHandler : IRequestHandler<RevokeDeviceCommand, bool>
    {
        private readonly AppDbContext _db;

        public RevokeDeviceCommandHandler(AppDbContext db)
        {
            _db = db;
        }

        public async Task<bool> Handle(RevokeDeviceCommand request, CancellationToken cancellationToken)
        {
            var devicePin = await _db.UserDevicePins
                .FirstOrDefaultAsync(p => p.UserId == request.UserId && p.DeviceId == request.DeviceId && p.CompanyId == request.CompanyId, cancellationToken);

            if (devicePin == null) return false;

            _db.UserDevicePins.Remove(devicePin);
            await _db.SaveChangesAsync(cancellationToken);
            return true;
        }
    }
}