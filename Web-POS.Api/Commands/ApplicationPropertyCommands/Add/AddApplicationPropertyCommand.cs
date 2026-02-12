using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;
using FluentValidation;
using MediatR;

namespace Products.Api.Commands.ApplicationPropertyCommands.Add
{
    public class AddApplicationPropertyCommand : IRequest<ApplicationPropertyDto>
    {
        public CreateApplicationPropertyRequest Request { get; }
        public int CompanyId { get; }

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
                var newentity = await _service.Create(command.Request, command.CompanyId);
                return newentity;
            }
        }
        public class AddApplicationPropertyCommandValidator : AbstractValidator<AddApplicationPropertyCommand>
        {
            public AddApplicationPropertyCommandValidator()
            {
                RuleFor(o => o.Request.Name).NotNull().NotEmpty().WithMessage("Property Name must not be null.");
                RuleFor(o => o.Request.Value).NotNull().NotEmpty().WithMessage("Property Value must not be null.");
            }
        }
    }
}
