using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductTaxQuery
{
    public class GetProductTaxesByProductIdQuery : IRequest<List<ProductTaxDto>>
    {
        public int ProductId { get; set; }
        public int CompanyId { get; set; }
        public class GetProductTaxesByProductIdQueryHandler : IRequestHandler<GetProductTaxesByProductIdQuery, List<ProductTaxDto>>
        {
            private readonly ProductTaxRepository _repository;
            public GetProductTaxesByProductIdQueryHandler(ProductTaxRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<ProductTaxDto>> Handle(GetProductTaxesByProductIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByProductIdAsync(request.ProductId, request.CompanyId);
                return entities.Select(MapperProductTax.MapToProductTaxDto).ToList();
            }
        }
    }
    public class GetProductTaxesByProductIdQueryValidator : AbstractValidator<GetProductTaxesByProductIdQuery>
    {
        public GetProductTaxesByProductIdQueryValidator()
        {
            RuleFor(x => x.ProductId).GreaterThan(0).WithMessage("Product ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}