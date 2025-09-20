using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentCategoryQuery
{
    public class GetDCByIdQuery : IRequest<DocumentCategoryDto?>
    {
        public int Id { get; set; }
        public GetDCByIdQuery(int id)
        {
            Id = id;
        }
    }
    public class GetDCByIdHandler : IRequestHandler<GetDCByIdQuery, DocumentCategoryDto?>
    {
        private readonly DocumentCategoryRepository _repository;
        public GetDCByIdHandler(DocumentCategoryRepository repository)
        {
            _repository = repository;
        }
        public async Task<DocumentCategoryDto?> Handle(GetDCByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id);
            if (entity is null)
            {
                return null;
            }
            return MapperDocumentCategory.MapDocumentCategory(entity);
        }
    }
}
