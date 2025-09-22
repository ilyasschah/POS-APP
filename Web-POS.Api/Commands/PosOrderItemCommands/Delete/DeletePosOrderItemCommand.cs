using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.PosOrderItemCommands.Delete
{
    public class DeletePosOrderItemCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public DeletePosOrderItemCommand (int id)
        {
            Id = id;
        }

        public class DeletePosOrderItemCommandHandler : IRequestHandler<DeletePosOrderItemCommand, bool>
        {
            private readonly PosOrderItemService _service;

            public DeletePosOrderItemCommandHandler(PosOrderItemService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePosOrderItemCommand command, CancellationToken cancellationToken)
            {
                return _service.DeleteAsync(command.Id);
            }
        }
    }
}