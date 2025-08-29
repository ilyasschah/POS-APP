using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentItemQuery
{
    public class GetAllDocumentItemQuery : IRequest<List<DocumentItemDto>>
    {
        public class GetAllDocumentItemQueryHandler : IRequestHandler<GetAllDocumentItemQuery, List<DocumentItemDto>>
        {
            private readonly DocumentItemRepository _documentItemRepository;
            public GetAllDocumentItemQueryHandler(DocumentItemRepository documentItemRepository)
            {
                _documentItemRepository = documentItemRepository;
            }
            public async Task<List<DocumentItemDto>> Handle(GetAllDocumentItemQuery request, CancellationToken cancellationToken)
            {
                var documentitem = await _documentItemRepository.GetDocumentItemsAsync();
                return documentitem.Select(MapperDocumentItem.MapToDocumentItem).ToList();
            }
        }
    }
}
