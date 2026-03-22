using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.DocumentCategoryQuery
{
    public class GetDCByIdQuery : IRequest<DocumentCategoryDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public GetDCByIdQuery(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
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
            var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
            if (entity is null)
            {
                return null;
            }
            return MapperDocumentCategory.MapDocumentCategory(entity);
        }
    }
    public class GetDCByIdQueryValidator : AbstractValidator<GetDCByIdQuery>
    {
        public GetDCByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Document Category ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
