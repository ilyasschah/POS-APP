using MediatR;
using Api.Services;

namespace Api.Commands.DocumentCategoryCommands.Delete
{
    public class DeleteDocumentCategoryCommand : IRequest<bool>
    {
        public int Id { get; }
        public DeleteDocumentCategoryCommand(int id)
        {
            Id = id;
        }
        public class DeleteDocumentCategoryCommandHandler : IRequestHandler<DeleteDocumentCategoryCommand, bool>
        {
            private readonly DocumentCategoryService _service;
            public DeleteDocumentCategoryCommandHandler(DocumentCategoryService service)
            {
                _service = service;
            }
            public Task<bool> Handle(DeleteDocumentCategoryCommand request, CancellationToken cancellationToken)
            {
                return _service.Delete(request.Id );
            }
        }
    }
}
