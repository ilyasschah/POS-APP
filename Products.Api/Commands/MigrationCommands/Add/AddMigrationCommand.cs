using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.MigrationCommands.Add
{
    public class AddMigrationCommand : IRequest<MigrationDto>
    {
        public CreateMigrationRequest Request { get; }

        public AddMigrationCommand(CreateMigrationRequest request)
        {
            Request = request;
        }

        public class AddMigrationCommandHandler : IRequestHandler<AddMigrationCommand, MigrationDto>
        {
            private readonly MigrationService _service;

            public AddMigrationCommandHandler(MigrationService service)
            {
                _service = service;
            }

            public async Task<MigrationDto> Handle(AddMigrationCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperMigration.MapToMigrationDto(entity);
            }
        }

        public class AddMigrationCommandValidator : AbstractValidator<AddMigrationCommand>
        {
            public AddMigrationCommandValidator()
            {
                RuleFor(c => c.Request.Version).NotEmpty().MaximumLength(100);
                RuleFor(c => c.Request.FileName).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Module).MaximumLength(100).When(x => x.Request.Module != null);
            }
        }
    }
}
