using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ApplicationPropertyCommands.Add
{
    public class AddApplicationPropertyCommand : IRequest<ApplicationPropertyDto>
    {
        public CreateApplicationPropertyRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddApplicationPropertyCommand(CreateApplicationPropertyRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddApplicationPropertyCommandHandler : IRequestHandler<AddApplicationPropertyCommand, ApplicationPropertyDto>
        {
            private readonly ApplicationPropertyService _service;

            public AddApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public async Task<ApplicationPropertyDto> Handle(AddApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }

        public class AddApplicationPropertyCommandValidator : AbstractValidator<AddApplicationPropertyCommand>
        {
            public AddApplicationPropertyCommandValidator()
            {
                RuleFor(o => o.Request.Name).NotNull().NotEmpty().WithMessage("Property Name must not be empty.");
                RuleFor(o => o.Request.Value).NotNull().NotEmpty().WithMessage("Property Value must not be empty.");
                RuleFor(o => o.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}