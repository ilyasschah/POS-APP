using Products.Api.Models;
using Products.Api.Services;
using FluentValidation;
using MediatR;

namespace Products.Api.Commands.ApplicationPropertyCommands.Update
{
    public class UpdateApplicationPropertyCommand : IRequest<bool>
    {
        public string OriginalName { get; }
        public UpdateApplicationPropertyRequest Request { get; }

        public UpdateApplicationPropertyCommand(string originalName, UpdateApplicationPropertyRequest request)
        {
            OriginalName = originalName;
            Request = request;
        }

        public class UpdateApplicationPropertyCommandHandler
            : IRequestHandler<UpdateApplicationPropertyCommand, bool>
        {
            private readonly ApplicationPropertyService _service;

            public UpdateApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.OriginalName, command.Request);
            }
        }

        public class UpdateApplicationPropertyCommandValidator : AbstractValidator<UpdateApplicationPropertyCommand>
        {
            public UpdateApplicationPropertyCommandValidator()
            {
                RuleFor(c => c.OriginalName).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(255);
            }
        }
    }
}
