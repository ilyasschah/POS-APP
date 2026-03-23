using Api.Helpers;
using Api.Models;
using Api.Repository;
using MediatR;

namespace Api.Queries.DocumentTypeQuery
{
    public class GetDocumentTypeByIdQuery(int id) : IRequest<DocumentTypeDto?>
    {
        public int Id { get; set; } = id;
        public int CompanyId { get; set; }
        public class GetDocumentTypeByIdHandler : IRequestHandler<GetDocumentTypeByIdQuery, DocumentTypeDto?>
        {
            private readonly DocumentTypeRepository _repository;

            public GetDocumentTypeByIdHandler(DocumentTypeRepository repository) => _repository = repository;

            public async Task<DocumentTypeDto?> Handle(GetDocumentTypeByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                if (entity == null || entity.Id == 0)
                {
                   return  null;
                }
                return MapperDocumentType.MapToDocumentTypeDto(entity);
            }
        }
    }
    
}
