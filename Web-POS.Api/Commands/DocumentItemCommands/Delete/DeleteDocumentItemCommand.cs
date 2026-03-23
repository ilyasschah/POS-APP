using MediatR;
using Api.Services;

namespace Api.Commands.DocumentItemCommands.Delete
{
    public class DeleteDocumentItemCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public DeleteDocumentItemCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteDocumentItemCommandHandler : IRequestHandler<DeleteDocumentItemCommand, bool>
        {
            private readonly DocumentItemService _documentItemService;

            public DeleteDocumentItemCommandHandler(DocumentItemService documentItemService)
            {
                _documentItemService = documentItemService;
            }

            public async Task<bool> Handle(DeleteDocumentItemCommand request, CancellationToken cancellationToken)
            {
                return await _documentItemService.DeleteAsync(request.Id, request.CompanyId);
            }
        }
    }
}