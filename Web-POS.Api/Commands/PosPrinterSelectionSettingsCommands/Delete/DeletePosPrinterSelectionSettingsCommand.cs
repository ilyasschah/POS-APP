using MediatR;
using Api.Services;

namespace Api.Commands.PosPrinterSelectionSettingsCommands.Delete
{
    public class DeletePosPrinterSelectionSettingsCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePosPrinterSelectionSettingsCommand(int id)
        {
            Id = id;
        }

        public class DeletePosPrinterSelectionSettingsCommandHandler
            : IRequestHandler<DeletePosPrinterSelectionSettingsCommand, bool>
        {
            private readonly PosPrinterSelectionSettingsService _service;

            public DeletePosPrinterSelectionSettingsCommandHandler(PosPrinterSelectionSettingsService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePosPrinterSelectionSettingsCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
