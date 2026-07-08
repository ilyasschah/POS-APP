using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Queries.FloorPlanTableQuery
{
    public class GetFloorPlanTableByNameQuery : IRequest<FloorPlanTableDto?>
    {
        public required string Name { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetFloorPlanTableByNameHandler : IRequestHandler<GetFloorPlanTableByNameQuery, FloorPlanTableDto?>
    {
        private readonly FloorPlanTableService _service;

        public GetFloorPlanTableByNameHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<FloorPlanTableDto?> Handle(GetFloorPlanTableByNameQuery request, CancellationToken cancellationToken)
        {
            return await _service.GetByNameAsync(request.Name, request.CompanyId);
        }
    }
}