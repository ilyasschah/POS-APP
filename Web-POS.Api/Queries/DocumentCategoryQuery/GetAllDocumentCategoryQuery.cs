using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.DocumentCategoryQuery
{
    public class GetAllDocumentCategoryQuery : IRequest<List<DocumentCategoryDto>>
    {
        public int CompanyId { get; set; }
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
            var entities = await _repository.GetAllAsync(request.CompanyId);
            return entities.Select(MapperDocumentCategory.MapDocumentCategory).ToList();
        }
    }
    public class GetAllDocumentCategoryQueryValidator : AbstractValidator<GetAllDocumentCategoryQuery>
    {
        public GetAllDocumentCategoryQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}

