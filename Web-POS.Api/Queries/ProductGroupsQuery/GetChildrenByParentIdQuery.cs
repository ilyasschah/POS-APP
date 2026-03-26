using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;
using FluentValidation;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetProductGroupChildrenQuery : IRequest<List<ProductGroupDto>>
    {
        public int ParentId { get; set; }
        public int CompanyId { get; set; }

        public class GetProductGroupChildrenHandler : IRequestHandler<GetProductGroupChildrenQuery, List<ProductGroupDto>>
        {
            private readonly ProductGroupRepository _repository;

            public GetProductGroupChildrenHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductGroupDto>> Handle(GetProductGroupChildrenQuery request, CancellationToken cancellationToken)
            {
                var children = await _repository.GetChildrenAsync(request.ParentId, request.CompanyId);
                return children.Select(MapperProductGroup.MapToDto).ToList();
            }
        }
    }
    public class GetProductGroupChildrenQueryValidator : AbstractValidator<GetProductGroupChildrenQuery>
    {
        public GetProductGroupChildrenQueryValidator()
        {
            RuleFor(x => x.ParentId).GreaterThan(0).WithMessage("Parent ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}