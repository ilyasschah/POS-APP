using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentItemCommands.Add
{
    public class AddDocumentItemCommand : IRequest<DocumentItemDto>
    {
        public CreateDocumentItemRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddDocumentItemCommand(CreateDocumentItemRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddDocumentItemCommandHandler : IRequestHandler<AddDocumentItemCommand, DocumentItemDto>
        {
            private readonly DocumentItemService _documentItemService;

            public AddDocumentItemCommandHandler(DocumentItemService documentItemService)
            {
                _documentItemService = documentItemService;
            }

            public async Task<DocumentItemDto> Handle(AddDocumentItemCommand request, CancellationToken cancellationToken)
            {
                return await _documentItemService.CreateAsync(request.Request, request.CompanyId);
            }
        }
    }
}