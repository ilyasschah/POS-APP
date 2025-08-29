using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentItemTaxQuery
{
    public class GetByDocumentitemTaxByIdQuery(int id) : IRequest<DocumentItemTaxDto?>
    {
        public int Id { get; set; } = id;
        public class GetByDocumentitemTaxByIdQueryHandler : IRequestHandler<GetByDocumentitemTaxByIdQuery, DocumentItemTaxDto?>
        {
            private readonly DocumentItemTaxRepository _repository;
            public GetByDocumentitemTaxByIdQueryHandler(DocumentItemTaxRepository repository)
            {
                _repository = repository;
            }
            public async Task<DocumentItemTaxDto?> Handle(GetByDocumentitemTaxByIdQuery request , CancellationToken cancellationToken)
            {
                var entity = await _repository.Getbydocumentidtoupdated(request.Id);
                if (entity == null || entity.DocumentItemId == 0)
                {
                    return null;
                }
                return new DocumentItemTaxDto
                {
                    DocumentItemId = entity.DocumentItemId,
                    TaxName = entity.Tax?.Name,
                    Amount = entity.Amount
                };
            }
        }
    }
}
