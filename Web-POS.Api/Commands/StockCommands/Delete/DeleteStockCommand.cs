using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.StockCommands.Delete
{
    public class DeleteStockCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; }

        public DeleteStockCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteStockCommandHandler : IRequestHandler<DeleteStockCommand, bool>
        {
            private readonly StockService _stockService;
            public DeleteStockCommandHandler(StockService stockService)
            {
                _stockService = stockService;
            }
            public Task<bool> Handle(DeleteStockCommand request, CancellationToken cancellationToken)
            {
                return _stockService.Delete(request.Id,request.CompanyId);
            }
        }
    }
}

