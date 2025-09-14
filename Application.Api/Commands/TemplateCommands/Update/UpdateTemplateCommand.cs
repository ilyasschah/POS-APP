using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.TemplateCommands.Update
{
    public class UpdateTemplateCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateTemplateRequest Request { get; }

        public UpdateTemplateCommand(int id, UpdateTemplateRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateTemplateCommandHandler
            : IRequestHandler<UpdateTemplateCommand, bool>
        {
            private readonly TemplateService _service;

            public UpdateTemplateCommandHandler(TemplateService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateTemplateCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateTemplateCommandValidator : AbstractValidator<UpdateTemplateCommand>
        {
            public UpdateTemplateCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Value).NotEmpty();
            }
        }
    }
}
