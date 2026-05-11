using MediatR;
using Api.Models;
using Api.Services;
using FluentValidation;

namespace Api.Commands.UserDevicePinCommands;

public class SetDevicePinCommand : IRequest<string>
{
    public SetDevicePinRequest Request { get; set; }
    public int CompanyId { get; set; }

    public SetDevicePinCommand(SetDevicePinRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class SetDevicePinCommandHandler : IRequestHandler<SetDevicePinCommand, string>
    {
        private readonly UserDevicePinService _service;

        public SetDevicePinCommandHandler(UserDevicePinService service)
        {
            _service = service;
        }

        public async Task<string> Handle(SetDevicePinCommand request, CancellationToken cancellationToken)
        {
            return await _service.SetDevicePinAsync(request.Request, request.CompanyId);
        }
    }
    public class SetDevicePinCommandValidator : AbstractValidator<SetDevicePinCommand>
    {
        public SetDevicePinCommandValidator()
        {
            RuleFor(c => c.Request.UserId).GreaterThan(0).WithMessage("User ID must be greater than 0.");
            RuleFor(c => c.Request.DeviceId).NotNull().NotEmpty().WithMessage("Device ID is required.");
            RuleFor(c => c.Request.Pin).NotNull().NotEmpty().MinimumLength(4).WithMessage("PIN must be at least 4 digits.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be greater than 0.");
        }
    }
}