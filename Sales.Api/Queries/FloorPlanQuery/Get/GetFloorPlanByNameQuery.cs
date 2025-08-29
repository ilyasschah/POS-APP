using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.FloorPlanQuery.Get
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