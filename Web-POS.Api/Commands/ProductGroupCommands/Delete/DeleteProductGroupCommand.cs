using MediatR;
using Api.Services;

namespace Api.Commands.ProductGroupCommands.Delete
{
    public class DeleteProductGroupCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteProductGroupCommand(int id)
        {
            Id = id;
        }

        public class DeleteProductGroupCommandHandler : IRequestHandler<DeleteProductGroupCommand, bool>
        {
            private readonly ProductGroupService _service;

            public DeleteProductGroupCommandHandler(ProductGroupService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteProductGroupCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
