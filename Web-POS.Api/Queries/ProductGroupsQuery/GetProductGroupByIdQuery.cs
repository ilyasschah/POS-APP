using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetProductGroupByIdQuery : IRequest<ProductGroupDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetProductGroupByIdQueryHandler : IRequestHandler<GetProductGroupByIdQuery, ProductGroupDto?>
        {
            private readonly ProductGroupRepository _repository;

            public GetProductGroupByIdQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductGroupDto?> Handle(GetProductGroupByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperProductGroup.MapToDto(entity);
            }
        }
    }
    public class GetProductGroupByIdQueryValidator : AbstractValidator<GetProductGroupByIdQuery>
    {
        public GetProductGroupByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Product Group ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
