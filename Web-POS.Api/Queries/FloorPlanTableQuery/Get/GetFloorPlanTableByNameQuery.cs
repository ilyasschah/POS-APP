using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using System.Threading;
using System.Threading.Tasks;

namespace Products.Api.Queries.FloorPlanTableQuery.Get
{
    public class GetFloorPlanTableByNameQuery : IRequest<FloorPlanTableDto?>
    {
        public string Name { get; set; }

        public class GetFloorPlanTableByNameQueryHandler : IRequestHandler<GetFloorPlanTableByNameQuery, FloorPlanTableDto?>
        {
            private readonly FloorPlanTableRepository _repository;

            public GetFloorPlanTableByNameQueryHandler(FloorPlanTableRepository repository)
            {
                _repository = repository;
            }

            public async Task<FloorPlanTableDto?> Handle(GetFloorPlanTableByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperFloorPlanTable.MapToFloorPlanTableDto(entity);
            }
        }
    }
}