// FILE: Products.Api.Queries\StockControlQuery\GetStockControlByIdQuery.cs

using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.StockControlQuery;

public class GetStockControlByIdQuery : IRequest<StockControlDto?>
{
    public int Id { get; }
    public GetStockControlByIdQuery(int id) { Id = id; }

    public class GetStockControlByIdQueryHandler : IRequestHandler<GetStockControlByIdQuery, StockControlDto?>
    {
        private readonly StockControlRepository _repository;

        public GetStockControlByIdQueryHandler(StockControlRepository repository)
        {
            _repository = repository;
        }

        public async Task<StockControlDto?> Handle(GetStockControlByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id);
            return entity == null ? null : MapperStockControl.MapToStockControlDto(entity);
        }
    }
}
