using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.MigrationCommands.Update
{
    public class UpdateMigrationCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateMigrationRequest Request { get; }

        public UpdateMigrationCommand(int id, UpdateMigrationRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateMigrationCommandHandler : IRequestHandler<UpdateMigrationCommand, bool>
        {
            private readonly MigrationService _service;

            public UpdateMigrationCommandHandler(MigrationService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateMigrationCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateMigrationCommandValidator : AbstractValidator<UpdateMigrationCommand>
        {
            public UpdateMigrationCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Version).NotEmpty().MaximumLength(100);
                RuleFor(c => c.Request.FileName).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Module).MaximumLength(100).When(x => x.Request.Module != null);
            }
        }
    }
}
