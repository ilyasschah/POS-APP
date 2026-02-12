using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentTypeQuery
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
