using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.FloorPlanCommands.Delete
{
    public class DeleteFloorPlanCommand : IRequest<bool>
    {
        public int Id { get; set; }

        public class DeleteFloorPlanCommandHandler : IRequestHandler<DeleteFloorPlanCommand, bool>
        {
            private readonly FloorPlanService _service;

            public DeleteFloorPlanCommandHandler(FloorPlanService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteFloorPlanCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}