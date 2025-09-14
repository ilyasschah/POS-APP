using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.MigrationCommands.Delete
{
    public class DeleteMigrationCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteMigrationCommand(int id)
        {
            Id = id;
        }

        public class DeleteMigrationCommandHandler : IRequestHandler<DeleteMigrationCommand, bool>
        {
            private readonly MigrationService _service;

            public DeleteMigrationCommandHandler(MigrationService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteMigrationCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
