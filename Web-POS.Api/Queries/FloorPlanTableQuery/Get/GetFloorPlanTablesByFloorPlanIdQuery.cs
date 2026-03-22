using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.FloorPlanTableQuery.Get
{
    public class GetFloorPlanTablesByFloorPlanIdQuery : IRequest<List<FloorPlanTableDto>>
    {
        public int FloorPlanId { get; set; }

        public class GetFloorPlanTablesByFloorPlanIdQueryHandler : IRequestHandler<GetFloorPlanTablesByFloorPlanIdQuery, List<FloorPlanTableDto>>
        {
            private readonly FloorPlanTableRepository _repository;

            public GetFloorPlanTablesByFloorPlanIdQueryHandler(FloorPlanTableRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<FloorPlanTableDto>> Handle(GetFloorPlanTablesByFloorPlanIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByFloorPlanIdAsync(request.FloorPlanId);
                return entities.Select(MapperFloorPlanTable.MapToFloorPlanTableDto).ToList();
            }
        }
    }
}