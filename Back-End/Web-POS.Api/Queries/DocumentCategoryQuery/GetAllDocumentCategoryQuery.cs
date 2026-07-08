using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentCategoryQuery
{
    public class GetAllDocumentCategoryQuery : IRequest<List<DocumentCategoryDto>>
    {
    }
    public class GetAllDocumentCategoryHandler : IRequestHandler<GetAllDocumentCategoryQuery, List<DocumentCategoryDto>>
    {
        private readonly DocumentCategoryRepository _repository;

        public GetAllDocumentCategoryHandler(DocumentCategoryRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<DocumentCategoryDto>> Handle(GetAllDocumentCategoryQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync();
            return entities.Select(MapperDocumentCategory.MapDocumentCategory).ToList();
        }
    }
}
