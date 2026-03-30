using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.DocumentItemTaxQuery
{
    public class GetDocumentItemTaxByIdsQuery : IRequest<DocumentItemTaxDto?>
    {
        public int DocumentItemId { get; set; }
        public int TaxId { get; set; }
        public int CompanyId { get; set; }

        public GetDocumentItemTaxByIdsQuery(int documentItemId, int taxId, int companyId)
        {
            DocumentItemId = documentItemId;
            TaxId = taxId;
            CompanyId = companyId;
        }

        public class GetDocumentItemTaxByIdsQueryHandler : IRequestHandler<GetDocumentItemTaxByIdsQuery, DocumentItemTaxDto?>
        {
            private readonly DocumentItemTaxRepository _repository;

            public GetDocumentItemTaxByIdsQueryHandler(DocumentItemTaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<DocumentItemTaxDto?> Handle(GetDocumentItemTaxByIdsQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdsAsync(request.DocumentItemId, request.TaxId, request.CompanyId);
                return entity == null ? null : MapperDocumentItemTax.MapToDocumentItemTaxDto(entity);
            }
        }
    }
}