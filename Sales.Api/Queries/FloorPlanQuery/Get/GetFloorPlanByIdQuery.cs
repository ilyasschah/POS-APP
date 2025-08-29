using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.FloorPlanQuery.Get
{
    public class GetFloorPlanByIdQuery : IRequest<FloorPlanDto?>
    {
        public int Id { get; set; }

        public class GetFloorPlanByIdQueryHandler : IRequestHandler<GetFloorPlanByIdQuery, FloorPlanDto?>
        {
            private readonly FloorPlanRepository _repository;

            public GetFloorPlanByIdQueryHandler(FloorPlanRepository repository)
            {
                _repository = repository;
            }

            public async Task<FloorPlanDto?> Handle(GetFloorPlanByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperFloorPlan.MapToFloorPlanDto(entity);
            }
        }
    }
}