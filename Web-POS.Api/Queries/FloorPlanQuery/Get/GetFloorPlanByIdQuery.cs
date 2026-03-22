using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.FloorPlanQuery.Get
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