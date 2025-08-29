using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentQuery
{
    public class GetAllDocumentsQuery : IRequest<List<DocumentDto>>
    {
        public class GetAllDocumentsQueryHandler : IRequestHandler<GetAllDocumentsQuery, List<DocumentDto>>
        {
            private readonly DocumentRepository _repository;

            public GetAllDocumentsQueryHandler(DocumentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<DocumentDto>> Handle(GetAllDocumentsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperDocument.MapToDocumentDto).ToList();
            }
        }
    }
}