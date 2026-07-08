using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetAllProductGroupsQuery : IRequest<List<ProductGroupDto>>
    {
        public int CompanyId { get; set; }
        public class GetAllProductGroupsQueryHandler : IRequestHandler<GetAllProductGroupsQuery, List<ProductGroupDto>>
        {
            private readonly ProductGroupRepository _repository;

            public GetAllProductGroupsQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductGroupDto>> Handle(GetAllProductGroupsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperProductGroup.MapToDto).ToList();
            }
        }
    }
    public class GetAllProductGroupsQueryValidator : AbstractValidator<GetAllProductGroupsQuery>
    {
        public GetAllProductGroupsQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
