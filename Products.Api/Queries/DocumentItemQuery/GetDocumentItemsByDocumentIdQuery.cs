using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentItemQuery
{
    public class GetDocumentItemsByDocumentIdQuery : IRequest<List<DocumentItemDto>>
    {
        public int DocumentId { get; set; }
        public class GetDocumentItemsByDocumentIdQueryHandler : IRequestHandler<GetDocumentItemsByDocumentIdQuery, List<DocumentItemDto>>
        {
            private readonly DocumentItemRepository _repository;
            public GetDocumentItemsByDocumentIdQueryHandler(DocumentItemRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<DocumentItemDto>> Handle(GetDocumentItemsByDocumentIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetDocumentItemsByDocumentIdAsync(request.DocumentId);
                return entities.Select(MapperDocumentItem.MapToDocumentItem).ToList();
            }
        }
    }
}