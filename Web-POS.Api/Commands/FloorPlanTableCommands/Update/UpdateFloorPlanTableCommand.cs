using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.FloorPlanTableCommands.Update
{
    public class UpdateFloorPlanTableCommand : IRequest<bool>
    {
        public required UpdateTableGeometryRequest Request { get; set; }
        public int CompanyId { get; set; }
    }

    public class UpdateFloorPlanTableHandler : IRequestHandler<UpdateFloorPlanTableCommand, bool>
    {
        private readonly FloorPlanTableService _service;

        public UpdateFloorPlanTableHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<bool> Handle(UpdateFloorPlanTableCommand request, CancellationToken cancellationToken)
        {
            return await _service.UpdateGeometryAsync(request.Request, request.CompanyId);
        }
    }
}