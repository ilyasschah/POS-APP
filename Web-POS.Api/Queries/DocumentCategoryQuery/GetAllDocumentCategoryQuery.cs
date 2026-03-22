using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentCategoryQuery
{
    public class GetAllDocumentCategoryQuery : IRequest<List<DocumentCategoryDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetAllDocumentCategoryHandler(DocumentCategoryRepository repository) : IRequestHandler<GetAllDocumentCategoryQuery, List<DocumentCategoryDto>>
    {
        private readonly DocumentCategoryRepository _repository = repository;

        public async Task<List<DocumentCategoryDto>> Handle(GetAllDocumentCategoryQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync(request.CompanyId);
            return entities.Select(MapperDocumentCategory.MapDocumentCategory).ToList();
        }
    }
}

