using MediatR;
using Api.Services;

namespace Api.Commands.DocumentItemExpirationDateCommands.Delete
{
    public class DeleteDocumentItemExpirationDateCommand : IRequest<bool>
    {
        public int DocumentItemId { get; }

        public DeleteDocumentItemExpirationDateCommand(int documentitemid)
        {
            DocumentItemId = documentitemid;
        }
    }
    public class DeleteDocumentItemExpirationDateCommandHandler : IRequestHandler<DeleteDocumentItemExpirationDateCommand, bool>
    {
        private readonly DocumentItemExpirationDateService _service;
        public DeleteDocumentItemExpirationDateCommandHandler(DocumentItemExpirationDateService service)
        {
            _service = service;
        }
        public Task<bool> Handle(DeleteDocumentItemExpirationDateCommand command, CancellationToken cancellationToken)
        {
            return _service.DeleteByDocumentItemId(command.DocumentItemId);
        }
    }
}
