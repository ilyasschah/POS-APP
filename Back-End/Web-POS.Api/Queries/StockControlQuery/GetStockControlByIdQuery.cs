using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.StockControlQuery
{
    public class GetStockControlByIdQuery : IRequest<StockControlDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetStockControlByIdQueryHandler : IRequestHandler<GetStockControlByIdQuery, StockControlDto?>
        {
            private readonly StockControlRepository _repository;

            public GetStockControlByIdQueryHandler(StockControlRepository repository)
            {
                _repository = repository;
            }

            public async Task<StockControlDto?> Handle(GetStockControlByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperStockControl.MapToStockControlDto(entity);
            }
        }
    }
    
}