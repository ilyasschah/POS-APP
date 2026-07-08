using MediatR;
using Api.Models;
using Api.Repository;

namespace Api.Queries.DocumentItemExpirationDateQuery
{
    /// <summary>All document-item expiration dates for a company — offline mirror pull (v39).</summary>
    public class GetAllDocumentItemExpirationDatesQuery : IRequest<List<DocumentItemExpirationDateDto>>
    {
        public int CompanyId { get; set; }

        public GetAllDocumentItemExpirationDatesQuery(int companyId) => CompanyId = companyId;

        public class Handler : IRequestHandler<GetAllDocumentItemExpirationDatesQuery, List<DocumentItemExpirationDateDto>>
        {
            private readonly DocumentItemExpirationDateRepository _repository;

            public Handler(DocumentItemExpirationDateRepository repository) => _repository = repository;

            public async Task<List<DocumentItemExpirationDateDto>> Handle(
                GetAllDocumentItemExpirationDatesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllByCompanyAsync(request.CompanyId);
                return entities
                    .Select(e => new DocumentItemExpirationDateDto
                    {
                        DocumentItemId = e.DocumentItemId,
                        ExpirationDate = e.ExpirationDate,
                    })
                    .ToList();
            }
        }
    }
}
