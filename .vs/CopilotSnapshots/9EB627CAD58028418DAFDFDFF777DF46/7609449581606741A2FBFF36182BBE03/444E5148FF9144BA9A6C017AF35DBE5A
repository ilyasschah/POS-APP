using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentCategoryQuery
{
    public class GetAllDocumentCategoryQuery : IRequest<List<DocumentCategoryDto>>
    {
        public class GetAllDocumentCategoryHandler(DocumentCategoryRepository repository) : IRequestHandler<GetAllDocumentCategoryQuery, List<DocumentCategoryDto>>
        {
            private readonly DocumentCategoryRepository _repository = repository;

            public async Task<List<DocumentCategoryDto>> Handle(GetAllDocumentCategoryQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperDocumentCategory.MapDocumentCategory).ToList();
            }
        }
    }
}

