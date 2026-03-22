using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.FloorPlanQuery.Get
{
    public class GetAllFloorPlansQuery : IRequest<List<FloorPlanDto>>
    {
        public class GetAllFloorPlansQueryHandler : IRequestHandler<GetAllFloorPlansQuery, List<FloorPlanDto>>
        {
            private readonly FloorPlanRepository _repository;

            public GetAllFloorPlansQueryHandler(FloorPlanRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<FloorPlanDto>> Handle(GetAllFloorPlansQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperFloorPlan.MapToFloorPlanDto).ToList();
            }
        }
    }
}
