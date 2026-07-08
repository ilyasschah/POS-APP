using MediatR;
using Api.Services;

namespace Api.Commands.FloorPlanTableCommands.Delete
{
    public class DeleteFloorPlanTableCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
    }

    public class DeleteFloorPlanTableHandler : IRequestHandler<DeleteFloorPlanTableCommand, bool>
    {
        private readonly FloorPlanTableService _service;

        public DeleteFloorPlanTableHandler(FloorPlanTableService service)
        {
            _service = service;
        }

        public async Task<bool> Handle(DeleteFloorPlanTableCommand request, CancellationToken cancellationToken)
        {
            return await _service.DeleteAsync(request.Id, request.CompanyId);
        }
    }
}