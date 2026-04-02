using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.FloorPlanTableCommand.Add
{
    public class AddFloorPlanTableCommand : IRequest<FloorPlanTableDto>
    {
        public required CreateFloorPlanTableRequest Request { get; set; }
        public int CompanyId { get; set; }
    }

    public class AddFloorPlanTableHandler : IRequestHandler<AddFloorPlanTableCommand, FloorPlanTableDto>
    {
        private readonly FloorPlanTableService _service;

        public AddFloorPlanTableHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<FloorPlanTableDto> Handle(AddFloorPlanTableCommand request, CancellationToken cancellationToken)
        {
            return await _service.CreateAsync(request.Request, request.CompanyId);
        }
    }
}