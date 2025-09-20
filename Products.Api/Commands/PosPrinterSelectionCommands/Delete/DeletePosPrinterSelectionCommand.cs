using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.PosPrinterSelectionCommands.Delete
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
            private readonly Products.Api.Services.PosPrinterSelectionService _service;

            public DeletePosPrinterSelectionCommandHandler(Products.Api.Services.PosPrinterSelectionService service)
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
