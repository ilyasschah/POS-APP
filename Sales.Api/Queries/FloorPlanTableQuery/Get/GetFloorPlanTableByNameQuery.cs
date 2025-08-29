using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;
using System.Threading;
using System.Threading.Tasks;

namespace Sales.Api.Queries.FloorPlanTableQuery.Get
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