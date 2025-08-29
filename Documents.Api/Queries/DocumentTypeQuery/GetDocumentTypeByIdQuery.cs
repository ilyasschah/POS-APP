using Documents.Api.Models.DocumentTypes;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentTypeQuery
{
    public class GetDocumentTypeByIdQuery(int id) : IRequest<DocumentTypeDto?>
    {
        public int Id { get; set; } = id;
        public class GetDocumentTypeByIdHandler : IRequestHandler<GetDocumentTypeByIdQuery, DocumentTypeDto?>
        {
            private readonly DocumentTypeRepository _repository;

            public GetDocumentTypeByIdHandler(DocumentTypeRepository repository) => _repository = repository;

            public async Task<DocumentTypeDto?> Handle(GetDocumentTypeByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                if (entity == null || entity.Id == 0)
                {
                    return null;
                }
                return new DocumentTypeDto
                {
                    Id = entity.Id,
                    Name = entity.Name,
                    Code = entity.Code,
                    DocumentCategoryId = entity.DocumentCategoryId,
                    WarehouseId = entity.WarehouseId,
                    StockDirection = entity.StockDirection,
                    EditorType = entity.EditorType,
                    PrintTemplate = entity.PrintTemplate,
                    PriceType = entity.PriceType,
                    LanguageKey = entity.LanguageKey
                };
            }
        }
    }
    
}
