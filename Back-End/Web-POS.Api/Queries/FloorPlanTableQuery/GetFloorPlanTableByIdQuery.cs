using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Queries.FloorPlanTableQuery
{
    public class GetFloorPlanTableByIdQuery : IRequest<FloorPlanTableDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetFloorPlanTableByIdHandler : IRequestHandler<GetFloorPlanTableByIdQuery, FloorPlanTableDto?>
    {
        private readonly FloorPlanTableService _service;

        public GetFloorPlanTableByIdHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<FloorPlanTableDto?> Handle(GetFloorPlanTableByIdQuery request, CancellationToken cancellationToken)
        {
            return await _service.GetByIdAsync(request.Id, request.CompanyId);
        }
    }
}