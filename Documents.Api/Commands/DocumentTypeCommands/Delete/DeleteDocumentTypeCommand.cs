using Documents.Api.Services;
using MediatR;

namespace Documents.Api.Commands.DocumentTypeCommands.Delete
{
    public record DeleteDocumentTypeCommand(int Id) : IRequest<bool>;

    public class DeleteDocumentTypeHandler : IRequestHandler<DeleteDocumentTypeCommand, bool>
    {
        private readonly DocumentTypeService _service;

        public DeleteDocumentTypeHandler(DocumentTypeService service) => _service = service;

        public async Task<bool> Handle(DeleteDocumentTypeCommand command, CancellationToken cancellationToken)
        {
            return await _service.Delete(command.Id);
        }
    }
}
