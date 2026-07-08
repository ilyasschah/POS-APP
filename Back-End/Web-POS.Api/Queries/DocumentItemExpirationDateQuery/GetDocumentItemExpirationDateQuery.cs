using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Queries.DocumentItemExpirationDateQuery
{
    public class GetDocumentItemExpirationDateQuery : IRequest<DocumentItemExpirationDateDto?>
    {
        public int DocumentItemId { get; set; }
        public int CompanyId { get; set; }

        public GetDocumentItemExpirationDateQuery(int documentItemId, int companyId)
        {
            DocumentItemId = documentItemId;
            CompanyId = companyId;
        }

        public class GetDocumentItemExpirationDateQueryHandler : IRequestHandler<GetDocumentItemExpirationDateQuery, DocumentItemExpirationDateDto?>
        {
            private readonly DocumentItemExpirationDateService _service;

            public GetDocumentItemExpirationDateQueryHandler(DocumentItemExpirationDateService service)
            {
                _service = service;
            }

            public async Task<DocumentItemExpirationDateDto?> Handle(GetDocumentItemExpirationDateQuery request, CancellationToken cancellationToken)
            {
                return await _service.Get(request.DocumentItemId, request.CompanyId);
            }
        }
    }
}