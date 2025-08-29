using Documents.Api.Helpers;
using Documents.Api.Models.DocumentTypes;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentTypeQuery
{
    public record GetAllDocumentTypesQuery : IRequest<List<DocumentTypeDto>>;

    public class GetAllDocumentTypesHandler : IRequestHandler<GetAllDocumentTypesQuery, List<DocumentTypeDto>>
    {
        private readonly DocumentTypeRepository _repository;

        public GetAllDocumentTypesHandler(DocumentTypeRepository repository) => _repository = repository;

        public async Task<List<DocumentTypeDto>> Handle(GetAllDocumentTypesQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync();
            return entities.Select(MapperDocumentType.MapToDocumentTypeDto).ToList();
        }
    }
}
