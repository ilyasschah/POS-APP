using Api.DataBase;
using Api.Models;
using Api.Services;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.UserDevicePinCommands;

public class RevokeDeviceCommand : IRequest<bool>
{
    public RevokeDeviceRequest Request { get; set; }
    public int CompanyId { get; set; }

    public RevokeDeviceCommand (RevokeDeviceRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class RevokeDeviceCommandHandler : IRequestHandler<RevokeDeviceCommand, bool>
    {
        private readonly UserDevicePinService _service;

        public RevokeDeviceCommandHandler(UserDevicePinService service)
        {
            _service = service;
        }

        public async Task<bool> Handle(RevokeDeviceCommand request, CancellationToken cancellationToken)
        {
          
            return await _service.RevokeDevicePinAsync(request.Request, request.CompanyId, cancellationToken);
        }
    }
}