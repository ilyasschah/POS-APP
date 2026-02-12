using Products.Api.Models;
using Products.Api.Services;
using FluentValidation;
using MediatR;

namespace Products.Api.Commands.ApplicationPropertyCommands.Update
{
    public class UpdateApplicationPropertyCommand : IRequest<ApplicationPropertyDto>
    {
        public UpdateApplicationPropertyRequest Request { get; }
        public int CompanyId { get; }

        public UpdateApplicationPropertyCommand(UpdateApplicationPropertyRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateApplicationPropertyCommandHandler
            : IRequestHandler<UpdateApplicationPropertyCommand, ApplicationPropertyDto>
        {
            private readonly ApplicationPropertyService _service;

            public UpdateApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public Task<ApplicationPropertyDto> Handle(UpdateApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                return _service.UpdateValue(command.Request, command.CompanyId);
            }
        }

        public class UpdateApplicationPropertyCommandValidator : AbstractValidator<UpdateApplicationPropertyCommand>
        {
            public UpdateApplicationPropertyCommandValidator()
            {
                RuleFor(cmd => cmd.Request.NewValue)
                    .NotNull()
                    .NotEmpty()
                    .WithMessage("New value must not be null or empty.");
            }
        }
    }
}
