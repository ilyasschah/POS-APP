using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.FloorPlanQuery.Get
{
    public class GetFloorPlanByNameQuery : IRequest<FloorPlanDto?>
    {
        public string Name { get; set; }

        public class GetFloorPlanByNameQueryHandler : IRequestHandler<GetFloorPlanByNameQuery, FloorPlanDto?>
        {
            private readonly FloorPlanRepository _repository;

            public GetFloorPlanByNameQueryHandler(FloorPlanRepository repository)
            {
                _repository = repository;
            }

            public async Task<FloorPlanDto?> Handle(GetFloorPlanByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperFloorPlan.MapToFloorPlanDto(entity);
            }
        }
    }
}