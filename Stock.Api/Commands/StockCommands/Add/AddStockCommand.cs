using MediatR;
using Stocks.Api.Models;
using Stocks.Api.Services;

namespace Stocks.Api.Commands.StockCommands.Add
{
    public class AddStockcommand(CreateStockRequest createStockRequest) : IRequest<bool>
    {
        public CreateStockRequest Request { get; set; } = createStockRequest;
        public class AddStockcommandHandler(StockService stockService) : IRequestHandler<AddStockcommand, bool>
        {
            private readonly StockService _stockService = stockService;
            public Task<bool> Handle(AddStockcommand request, CancellationToken cancellationToken)
            {
                return _stockService.Create(request.Request.Quantity, request.Request.WarehouseId,request.Request.ProductId);
            }
        }
    }
}

