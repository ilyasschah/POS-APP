// FILE: Products.Api.Commands\StockControlCommands\Delete\DeleteStockControlCommand.cs

using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.StockControlCommands.Delete;

public class DeleteStockControlCommand : IRequest<bool>
{
    public int Id { get; }

    public DeleteStockControlCommand(int id)
    {
        Id = id;
    }

    public class DeleteStockControlCommandHandler : IRequestHandler<DeleteStockControlCommand, bool>
    {
        private readonly StockControlService _service;

        public DeleteStockControlCommandHandler(StockControlService service)
        {
            _service = service;
        }

        public Task<bool> Handle(DeleteStockControlCommand request, CancellationToken cancellationToken)
        {
            return _service.Delete(request.Id);
        }
    }
}
