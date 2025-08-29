using MediatR;
using Products.Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Products.Api.Commands.VoidReasonCommands.Delete
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