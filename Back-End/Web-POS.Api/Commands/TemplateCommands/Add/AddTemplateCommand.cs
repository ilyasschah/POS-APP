using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Services;

namespace Api.Commands.TemplateCommands.Add
{
    public class AddTemplateCommand : IRequest<TemplateDto>
    {
        public CreateTemplateRequest Request { get; }

        public AddTemplateCommand(CreateTemplateRequest request)
        {
            Request = request;
        }

        public class AddTemplateCommandHandler
            : IRequestHandler<AddTemplateCommand, TemplateDto>
        {
            private readonly TemplateService _service;

            public AddTemplateCommandHandler(TemplateService service)
            {
                _service = service;
            }

            public async Task<TemplateDto> Handle(AddTemplateCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperTemplate.MapToTemplateDto(entity);
            }
        }

        public class AddTemplateCommandValidator : AbstractValidator<AddTemplateCommand>
        {
            public AddTemplateCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Value).NotEmpty();
            }
        }
    }
}
