using Api.Models;
using Api.Services;
using FluentValidation;
using MediatR;

namespace Api.Commands.SecurityKeyCommands
{
    public class UpdateSecurityKeyCommand : IRequest<bool>
    {
        public required UpdateSecurityKeyRequest Request { get; set; }
        public required int CompanyId { get; set; }
    }
    public class UpdateSecurityKeyHandler : IRequestHandler<UpdateSecurityKeyCommand, bool>
    {
        private readonly SecurityKeyService _service;

        public UpdateSecurityKeyHandler(SecurityKeyService service)
        {
            _service = service;
        }

        public async Task<bool> Handle(UpdateSecurityKeyCommand request, CancellationToken cancellationToken)
        {
            return await _service.UpdateAsync(request.Request, request.CompanyId);
        }
    }
    public class UpdateSecurityKeyValidator : AbstractValidator<UpdateSecurityKeyCommand>
    {
        public UpdateSecurityKeyValidator()
        {
            RuleFor(c => c.Request).NotNull().WithMessage("Request body is required.");
            RuleFor(c => c.Request.Name).NotEmpty().WithMessage("Name is required.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be greater than 0.");
        }
    }
}