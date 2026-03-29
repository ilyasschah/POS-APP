using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.StockControlQuery
{
    public class GetStockControlByProductIdQuery : IRequest<StockControlDto?>
    {
        public int ProductId { get; set; }
        public int CompanyId { get; set; }

        public class GetStockControlByProductIdQueryHandler : IRequestHandler<GetStockControlByProductIdQuery, StockControlDto?>
        {
            private readonly StockControlRepository _repository;

            public GetStockControlByProductIdQueryHandler(StockControlRepository repository)
            {
                _repository = repository;
            }

            public async Task<StockControlDto?> Handle(GetStockControlByProductIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByProductIdAsync(request.ProductId, request.CompanyId);
                return entity == null ? null : MapperStockControl.MapToStockControlDto(entity);
            }
        }
    }
}