using MediatR;
using Stocks.Api.Helpers;
using Stocks.Api.Models;
using Stocks.Api.Repository;

namespace Stocks.Api.Queries.StockQuery
{
    public class GetStockProductNameWarehouseNameQuery : IRequest<List<StockDto>>
    {
    }
    public class GetStockProductNameWarehouseNameQueryHandler : IRequestHandler<GetStockProductNameWarehouseNameQuery, List<StockDto>>
    {
        private readonly StockRepository _stockRepository;

        public GetStockProductNameWarehouseNameQueryHandler(StockRepository inventoryRepository)
        {
            _stockRepository = inventoryRepository;
        }
        public async Task<List<StockDto>> Handle(GetStockProductNameWarehouseNameQuery request, CancellationToken cancellationToken)
        {
            var stockEntities = await _stockRepository.GetAllProducts_warehouse_StocksAsync();
            return stockEntities.Select(MapperStock.MapToStock).ToList();
        }
    }
}