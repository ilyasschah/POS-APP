using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Services;

namespace Api.Commands.VoidReasonCommads.Delete
{
    public class DeleteVoidReasonCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteVoidReasonCommand(int id)
        {
            Id = id;
        }

        public class DeleteVoidReasonCommandHandler : IRequestHandler<DeleteVoidReasonCommand, bool>
        {
            private readonly VoidReasonService _service;

            public DeleteVoidReasonCommandHandler(VoidReasonService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteVoidReasonCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}