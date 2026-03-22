using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentQuery
{
    public class GetAllDocumentsQuery : IRequest<List<DocumentDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllDocumentsQueryHandler : IRequestHandler<GetAllDocumentsQuery, List<DocumentDto>>
        {
            private readonly DocumentRepository _repository;

            public GetAllDocumentsQueryHandler(DocumentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<DocumentDto>> Handle(GetAllDocumentsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperDocument.MapToDocumentDto).ToList();
            }
        }
    }
}