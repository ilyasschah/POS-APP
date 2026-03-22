using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentTypeQuery
{
    public class GetAllDocumentTypesQuery : IRequest<List<DocumentTypeDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetAllDocumentTypesHandler : IRequestHandler<GetAllDocumentTypesQuery, List<DocumentTypeDto>>
    {
        private readonly DocumentTypeRepository _repository;

        public GetAllDocumentTypesHandler(DocumentTypeRepository repository) => _repository = repository;

        public async Task<List<DocumentTypeDto>> Handle(GetAllDocumentTypesQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync(request.CompanyId);
            return entities.Select(MapperDocumentType.MapToDocumentTypeDto).ToList();
        }
    }
}
