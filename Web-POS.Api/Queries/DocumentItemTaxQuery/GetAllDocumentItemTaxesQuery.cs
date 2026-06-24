using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.DocumentItemTaxQuery
{
    /// <summary>All document-item taxes for a company — offline mirror pull (v39 schema clone).</summary>
    public class GetAllDocumentItemTaxesQuery : IRequest<List<DocumentItemTaxDto>>
    {
        public int CompanyId { get; set; }

        public GetAllDocumentItemTaxesQuery(int companyId) => CompanyId = companyId;

        public class Handler : IRequestHandler<GetAllDocumentItemTaxesQuery, List<DocumentItemTaxDto>>
        {
            private readonly DocumentItemTaxRepository _repository;

            public Handler(DocumentItemTaxRepository repository) => _repository = repository;

            public async Task<List<DocumentItemTaxDto>> Handle(
                GetAllDocumentItemTaxesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllByCompanyAsync(request.CompanyId);
                return entities.Select(MapperDocumentItemTax.MapToDocumentItemTaxDto).ToList();
            }
        }
    }
}
