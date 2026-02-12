// FILE: Products.Api.Queries\StockControlQuery\GetAllStockControlsQuery.cs

using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.StockControlQuery;

public class GetAllStockControlsQuery : IRequest<List<StockControlDto>>
{
    public int CompanyId { get; set; }

    public class GetAllStockControlsQueryHandler : IRequestHandler<GetAllStockControlsQuery, List<StockControlDto>>
    {
        private readonly StockControlRepository _repository;

        public GetAllStockControlsQueryHandler(StockControlRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<StockControlDto>> Handle(GetAllStockControlsQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync(request.CompanyId);
            return entities.Select(MapperStockControl.MapToStockControlDto).ToList();
        }
    }
}
