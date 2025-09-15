using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommands.Delete
{
    public class DeleteProductCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteProductCommand(int id)
        {
            Id = id;
        }

        public class DeleteProductCommandHandler : IRequestHandler<DeleteProductCommand, bool>
        {
            private readonly ProductService _service;

            public DeleteProductCommandHandler(ProductService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteProductCommand command, System.Threading.CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
