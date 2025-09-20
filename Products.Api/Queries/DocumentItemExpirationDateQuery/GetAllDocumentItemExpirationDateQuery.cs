using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Queries.DocumentItemExpirationDateQuery
{
    public class GetAllDocumentItemExpirationDateQuery : IRequest<List<DocumentItemExpirationDateDto>>
    {
        public class GetAllDocumentItemExpirationDateQueryHandler : IRequestHandler<GetAllDocumentItemExpirationDateQuery, List<DocumentItemExpirationDateDto>>
        {
            private readonly DocumentItemExpirationDateRepository _documentItemexpirationdateRepository;
            public GetAllDocumentItemExpirationDateQueryHandler(DocumentItemExpirationDateRepository documentItemexpirationdateRepository)
            {
                _documentItemexpirationdateRepository = documentItemexpirationdateRepository;
            }
            public async Task<List<DocumentItemExpirationDateDto>> Handle(GetAllDocumentItemExpirationDateQuery request, CancellationToken cancellationToken)
            {
                var documentitem = await _documentItemexpirationdateRepository.GetAllAsync();
                return documentitem.Select(MapperDocumentItemExpirationDate.MapperToDocumentItemExpirationDate).ToList();
            }
        }
    }
}
