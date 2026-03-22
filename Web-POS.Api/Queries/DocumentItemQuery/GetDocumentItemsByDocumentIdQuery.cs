using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentItemQuery
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