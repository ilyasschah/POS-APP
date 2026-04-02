using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Queries.FloorPlanTableQuery
{
    public class GetAllFloorPlanTablesQuery : IRequest<List<FloorPlanTableDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetAllFloorPlanTablesHandler : IRequestHandler<GetAllFloorPlanTablesQuery, List<FloorPlanTableDto>>
    {
        private readonly FloorPlanTableService _service;

        public GetAllFloorPlanTablesHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<List<FloorPlanTableDto>> Handle(GetAllFloorPlanTablesQuery request, CancellationToken cancellationToken)
        {
            return await _service.GetAllAsync(request.CompanyId);
        }
    }
}