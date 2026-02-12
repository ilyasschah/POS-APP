using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommands.Delete
{
    public class DeleteProductCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; } 

        public DeleteProductCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteProductCommandHandler : IRequestHandler<DeleteProductCommand, bool>
        {
            private readonly ProductService _service;

            public DeleteProductCommandHandler(ProductService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteProductCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id, command.CompanyId);
            }
        }
    }
}
