using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Services;

namespace Api.Commands.PosVoidCommands.Delete;

public class DeletePosVoidCommand : IRequest<bool>
{
    public string? Reason { get; set; }
    
    public class DeletePosVoidCommandHandler : IRequestHandler<DeletePosVoidCommand, bool>
    {
        private readonly PosVoidService _service;

        public DeletePosVoidCommandHandler(PosVoidService service)
        {
            _service = service;
        }

        public Task<bool> Handle(DeletePosVoidCommand command, CancellationToken cancellationToken)
        {
            return _service.Delete(command.Reason);
        }
    }
}