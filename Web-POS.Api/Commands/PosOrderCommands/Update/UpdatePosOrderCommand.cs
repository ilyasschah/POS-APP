using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.PosOrderCommands.Update
{
    public class DeletePosOrderCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePosOrderCommand(int id)
        {
            Id = id;
        }
        public class DeletePosOrderCommandHandler : IRequestHandler<DeletePosOrderCommand, bool>
        {
            private readonly PosOrderService _service;

            public DeletePosOrderCommandHandler(PosOrderService service)
            {
                _service = service;
            }
            public Task<bool> Handle(DeletePosOrderCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}