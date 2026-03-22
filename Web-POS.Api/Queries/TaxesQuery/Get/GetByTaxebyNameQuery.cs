using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.TaxesQuery.Get
{
    public class GetByTaxebyNameQuery : IRequest<TaxDto?>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }

        public class GetByTaxebyNameQueryHandler : IRequestHandler<GetByTaxebyNameQuery, TaxDto?>
        {
            private readonly TaxRepository _repository;

            public GetByTaxebyNameQueryHandler(TaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<TaxDto?> Handle(GetByTaxebyNameQuery request, CancellationToken cancellationToken)
            {
                var tax = await _repository.GetByNameAsync(request.Name, request.CompanyId);
                return tax == null ? null : MapperTax.MapToTaxDto(tax);
            }
        }

        public class GetByTaxebyNameQueryValidator : AbstractValidator<GetByTaxebyNameQuery>
        {
            public GetByTaxebyNameQueryValidator()
            {
                RuleFor(x => x.Name).NotEmpty().WithMessage("Tax name must be provided.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
