using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentCategoryQuery
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

