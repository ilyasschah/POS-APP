using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.DocumentItemTaxQuery.Get
{
    public class GetDocumentItemTaxesByDocumentItemIdQuery : IRequest<List<DocumentItemTaxDto>>
    {
        public int DocumentItemId { get; set; }
        public int CompanyId { get; set; }

        public GetDocumentItemTaxesByDocumentItemIdQuery(int documentItemId, int companyId)
        {
            DocumentItemId = documentItemId;
            CompanyId = companyId;
        }

        public class GetDocumentItemTaxesByDocumentItemIdQueryHandler : IRequestHandler<GetDocumentItemTaxesByDocumentItemIdQuery, List<DocumentItemTaxDto>>
        {
            private readonly DocumentItemTaxRepository _repository;

            public GetDocumentItemTaxesByDocumentItemIdQueryHandler(DocumentItemTaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<DocumentItemTaxDto>> Handle(GetDocumentItemTaxesByDocumentItemIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByDocumentItemIdAsync(request.DocumentItemId, request.CompanyId);
                return entities.Select(MapperDocumentItemTax.MapToDocumentItemTaxDto).ToList();
            }
        }
    }
}