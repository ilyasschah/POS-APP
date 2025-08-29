using Documents.Api.Services;
using MediatR;

namespace Documents.Api.Commands.DocumentCommands.Delete
{
    public class DeleteDocumentCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteDocumentCommand(int id)
        {
            Id = id;
        }
        public class DeleteDocumentCommandHandler : IRequestHandler<DeleteDocumentCommand, bool>
        {
            private readonly DocumentService _service;

            public DeleteDocumentCommandHandler(DocumentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteDocumentCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}