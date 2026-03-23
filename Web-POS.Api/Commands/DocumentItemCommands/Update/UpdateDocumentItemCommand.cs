using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentItemCommands.Update
{
    public class UpdateDocumentItemCommand : IRequest<bool>
    {
        public UpdateDocumentItemRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdateDocumentItemCommand(UpdateDocumentItemRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateDocumentItemCommandHandler : IRequestHandler<UpdateDocumentItemCommand, bool>
        {
            private readonly DocumentItemService _documentItemService;

            public UpdateDocumentItemCommandHandler(DocumentItemService documentItemService)
            {
                _documentItemService = documentItemService;
            }

            public async Task<bool> Handle(UpdateDocumentItemCommand request, CancellationToken cancellationToken)
            {
                return await _documentItemService.UpdateAsync(request.Request, request.CompanyId);
            }
        }
    }
}