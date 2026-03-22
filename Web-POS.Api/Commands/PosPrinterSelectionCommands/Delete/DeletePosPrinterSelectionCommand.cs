using MediatR;
using Api.Services;

namespace Api.Commands.PosPrinterSelectionCommands.Delete
{
    public class DeletePosPrinterSelectionCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePosPrinterSelectionCommand(int id)
        {
            Id = id;
        }

        public class DeletePosPrinterSelectionCommandHandler
            : IRequestHandler<DeletePosPrinterSelectionCommand, bool>
        {
            private readonly Services.PosPrinterSelectionService _service;

            public DeletePosPrinterSelectionCommandHandler(Services.PosPrinterSelectionService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePosPrinterSelectionCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
