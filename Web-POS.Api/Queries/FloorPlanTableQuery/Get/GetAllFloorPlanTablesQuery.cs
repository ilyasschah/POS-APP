using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.FloorPlanTableQuery.Get
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