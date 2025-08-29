using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.FloorPlanTableQuery.Get
{
    public class GetFloorPlanTableByIdQuery : IRequest<FloorPlanTableDto?>
    {
        public int Id { get; set; }

        public class GetFloorPlanTableByIdQueryHandler : IRequestHandler<GetFloorPlanTableByIdQuery, FloorPlanTableDto?>
        {
            private readonly FloorPlanTableRepository _repository;

            public GetFloorPlanTableByIdQueryHandler(FloorPlanTableRepository repository)
            {
                _repository = repository;
            }

            public async Task<FloorPlanTableDto?> Handle(GetFloorPlanTableByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperFloorPlanTable.MapToFloorPlanTableDto(entity);
            }
        }
    }
}