using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentItemExpirationDateQuery
{
    public class GetExpDateByDocumentIdQuery : IRequest<DocumentItemExpirationDateDto>
    {
        public int Documentitemid { get; set; }
        public GetExpDateByDocumentIdQuery(int documentitemid)
        {
            Documentitemid = documentitemid;
        }
        public class GetExpDateByDocumentIdQueryHandler : IRequestHandler<GetExpDateByDocumentIdQuery, DocumentItemExpirationDateDto>
        {
            private readonly DocumentItemExpirationDateRepository _repository;
            public GetExpDateByDocumentIdQueryHandler(DocumentItemExpirationDateRepository repository)
            {
                _repository = repository;
            }
            public async Task<DocumentItemExpirationDateDto> Handle(GetExpDateByDocumentIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.Getbydocumentidtoupdated(request.Documentitemid);
                return new DocumentItemExpirationDateDto
                {
                    DocumentItemId = entities.DocumentItemId,
                    ExpirationDate = entities.ExpirationDate,
                };
            }
        }
    }
}