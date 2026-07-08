using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductTaxQuery
{
    public class GetProductTaxesByTaxIdQuery : IRequest<List<ProductTaxDto>>
    {
        public int TaxId { get; set; }
        public int CompanyId { get; set; }

        public class GetProductTaxesByTaxIdQueryHandler : IRequestHandler<GetProductTaxesByTaxIdQuery, List<ProductTaxDto>>
        {
            private readonly ProductTaxRepository _repository;

            public GetProductTaxesByTaxIdQueryHandler(ProductTaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductTaxDto>> Handle(GetProductTaxesByTaxIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByTaxIdAsync(request.TaxId, request.CompanyId);
                return entities.Select(MapperProductTax.MapToProductTaxDto).ToList();
            }
        }
    }
    public class GetProductTaxesByTaxIdQueryValidator : AbstractValidator<GetProductTaxesByTaxIdQuery>
    {
        public GetProductTaxesByTaxIdQueryValidator()
        {
            RuleFor(x => x.TaxId).GreaterThan(0).WithMessage("Tax ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}