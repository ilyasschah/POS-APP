using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommentCommands.Delete
{
    public class DeleteProductCommentCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteProductCommentCommand(int id)
        {
            Id = id;
        }

        public class DeleteProductCommentCommandHandler : IRequestHandler<DeleteProductCommentCommand, bool>
        {
            private readonly ProductCommentService _service;

            public DeleteProductCommentCommandHandler(ProductCommentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteProductCommentCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
