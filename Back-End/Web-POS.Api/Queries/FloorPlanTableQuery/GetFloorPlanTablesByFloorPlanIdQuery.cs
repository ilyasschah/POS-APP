using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Queries.FloorPlanTableQuery
{
    public class GetFloorPlanTablesByFloorPlanIdQuery : IRequest<List<FloorPlanTableDto>>
    {
        public int FloorPlanId { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetFloorPlanTablesByFloorPlanIdHandler : IRequestHandler<GetFloorPlanTablesByFloorPlanIdQuery, List<FloorPlanTableDto>>
    {
        private readonly FloorPlanTableService _service;

        public GetFloorPlanTablesByFloorPlanIdHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<List<FloorPlanTableDto>> Handle(GetFloorPlanTablesByFloorPlanIdQuery request, CancellationToken cancellationToken)
        {
            return await _service.GetByFloorPlanIdAsync(request.FloorPlanId, request.CompanyId);
        }
    }
}