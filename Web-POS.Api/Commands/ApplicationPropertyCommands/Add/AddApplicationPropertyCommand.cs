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

        public AddApplicationPropertyCommand(CreateApplicationPropertyRequest request)
        {
            Request = request;
        }

        public class AddApplicationPropertyCommandHandler
            : IRequestHandler<AddApplicationPropertyCommand, ApplicationPropertyDto>
        {
            private readonly ApplicationPropertyService _service;

            public AddApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public async Task<ApplicationPropertyDto> Handle(AddApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperApplicationProperty.MapToApplicationPropertyDto(entity);
            }
        }

        public class AddApplicationPropertyCommandValidator : AbstractValidator<AddApplicationPropertyCommand>
        {
            public AddApplicationPropertyCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(255);
            }
        }
    }
}
