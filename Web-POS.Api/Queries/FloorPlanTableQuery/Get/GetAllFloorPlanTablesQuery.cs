using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.FloorPlanTableQuery.Get
{
    public class GetAllFloorPlanTablesQuery : IRequest<List<FloorPlanTableDto>>
    {
        public class GetAllFloorPlanTablesQueryHandler : IRequestHandler<GetAllFloorPlanTablesQuery, List<FloorPlanTableDto>>
        {
            private readonly FloorPlanTableRepository _repository;

            public GetAllFloorPlanTablesQueryHandler(FloorPlanTableRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<FloorPlanTableDto>> Handle(GetAllFloorPlanTablesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperFloorPlanTable.MapToFloorPlanTableDto).ToList();
            }
        }
    }
}