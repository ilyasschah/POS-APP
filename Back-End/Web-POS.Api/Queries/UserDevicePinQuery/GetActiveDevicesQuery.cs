using FluentValidation;
using MediatR;
using Api.Models;
using Api.Repository;

namespace Api.Queries.UserDevicePinQuery;

public class GetActiveDevicesQuery : IRequest<List<UserDevicePinDto>>
{
    public int CompanyId { get; set; }
    public int? UserId { get; set; }

    public class GetActiveDevicesQueryHandler : IRequestHandler<GetActiveDevicesQuery, List<UserDevicePinDto>>
    {
        private readonly UserDevicePinRepository _repository;
        private readonly Api.Master.Services.ITenantProvisioningService _provisioning;

        public GetActiveDevicesQueryHandler(
            UserDevicePinRepository repository,
            Api.Master.Services.ITenantProvisioningService provisioning)
        {
            _repository = repository;
            _provisioning = provisioning;
        }

        public async Task<List<UserDevicePinDto>> Handle(GetActiveDevicesQuery request, CancellationToken cancellationToken)
        {
            var devices = await _repository.GetActiveDevicesAsync(request.UserId, request.CompanyId, cancellationToken);
            if (devices.Count == 0) return devices;

            // The PIN rows live in the app DB and the terminal NAME lives in the
            // Master DB — two databases, so this is a lookup + merge, not a join.
            // Non-fatal: a control-plane hiccup must not blank the device list, it
            // just leaves the names null and the UI falls back to the id.
            try
            {
                var names = await _provisioning.GetDeviceNamesAsync(request.CompanyId, cancellationToken);
                foreach (var d in devices)
                {
                    if (names.TryGetValue(d.DeviceId, out var name)) d.DeviceName = name;
                }
            }
            catch
            {
                // Control plane unavailable — ids only.
            }

            return devices;
        }
    }

    public class GetActiveDevicesQueryValidator : AbstractValidator<GetActiveDevicesQuery>
    {
        public GetActiveDevicesQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0);
        }
    }
}