using MediatR;
using Products.Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Products.Api.Commands.FloorPlanTableCommands.Delete
{
    public class DeleteFloorPlanTableCommand : IRequest<bool>
    {
        public int Id { get; set; }

        public class DeleteFloorPlanTableCommandHandler : IRequestHandler<DeleteFloorPlanTableCommand, bool>
        {
            private readonly FloorPlanTableService _service;

            public DeleteFloorPlanTableCommandHandler(FloorPlanTableService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteFloorPlanTableCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}