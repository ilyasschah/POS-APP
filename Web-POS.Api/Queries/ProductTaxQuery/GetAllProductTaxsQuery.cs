using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductTaxQuery
{
    public class GetAllProductTaxesQuery : IRequest<List<ProductTaxDto>>
    {
        public int CompanyId { get; set; }
        public class GetAllProductTaxesQueryHandler : IRequestHandler<GetAllProductTaxesQuery, List<ProductTaxDto>>
        {
            private readonly ProductTaxRepository _repository;

            public GetAllProductTaxesQueryHandler(ProductTaxRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<ProductTaxDto>> Handle(GetAllProductTaxesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperProductTax.MapToProductTaxDto).ToList();
            }
        }
    }
    public class GetAllProductTaxesQueryValidator : AbstractValidator<GetAllProductTaxesQuery>
    {
        public GetAllProductTaxesQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}