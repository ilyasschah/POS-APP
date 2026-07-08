using MediatR;
using Api.Services;

namespace Api.Commands.PosPrinterSettingsCommands.Delete
{
    public class DeletePosPrinterSettingsCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePosPrinterSettingsCommand(int id)
        {
            Id = id;
        }

        public class DeletePosPrinterSettingsCommandHandler
            : IRequestHandler<DeletePosPrinterSettingsCommand, bool>
        {
            private readonly PosPrinterSettingsService _service;

            public DeletePosPrinterSettingsCommandHandler(PosPrinterSettingsService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePosPrinterSettingsCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
