using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;
namespace Documents.Api.Queries.DocumentItemExpirationDateQuery
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
