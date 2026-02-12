using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.StockQuery
{
    public class GetStockByIdQuery : IRequest<StockDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public GetStockByIdQuery(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }
        public class GetStockByIdQueryHandler : IRequestHandler<GetStockByIdQuery, StockDto?>
        {
            private readonly StockRepository _stockRepository;
            public GetStockByIdQueryHandler(StockRepository stockRepository)
            {
                _stockRepository = stockRepository;
            }
            public async Task<StockDto?> Handle(GetStockByIdQuery request, CancellationToken cancellationToken)
            {
                var stock = await _stockRepository.GetStockByIdQuery(request.Id, request.CompanyId);
                if (stock is null)
                {
                    return null;
                }
                return new StockDto
                {
                    Id = stock.Id,
                    ProductName = stock.Product.Name,
                    Quantity = stock.Quantity,
                    WarehouseName = stock.Warehouse.Name,
                    CompanyId = stock.CompanyId
                };
            }
        }
    }
}
