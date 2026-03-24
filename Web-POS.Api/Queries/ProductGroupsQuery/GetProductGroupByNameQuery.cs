using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetProductGroupByNameQuery : IRequest<bool>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }

        public class GetProductGroupByNameQueryHandler : IRequestHandler<GetProductGroupByNameQuery, bool>
        {
            private readonly ProductGroupRepository _repository;

            public GetProductGroupByNameQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<bool> Handle(GetProductGroupByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.IsNameUniqueAsync(request.Name, request.CompanyId);
                return entity;
            }
        }
    }
    public class GetProductGroupByNameQueryValidator : AbstractValidator<GetProductGroupByNameQuery>
    {
        public GetProductGroupByNameQueryValidator()
        {
            RuleFor(x => x.Name).NotEmpty().WithMessage("Product Group Name is required.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
