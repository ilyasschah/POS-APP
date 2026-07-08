using MediatR;
using Api.Services;

namespace Api.Commands.FiscalItemCommands.Delete
{
    public class DeleteFiscalItemCommand : IRequest<bool>
    {
        public int PLU { get; }

        public DeleteFiscalItemCommand(int plu)
        {
            PLU = plu;
        }

        public class DeleteFiscalItemCommandHandler : IRequestHandler<DeleteFiscalItemCommand, bool>
        {
            private readonly FiscalItemService _service;

            public DeleteFiscalItemCommandHandler(FiscalItemService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteFiscalItemCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.PLU);
            }
        }
    }
}