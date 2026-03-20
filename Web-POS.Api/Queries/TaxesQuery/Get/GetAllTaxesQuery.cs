using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.TaxesQuery.Get
{
    public class GetAllTaxesQuery : IRequest<List<TaxDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllTaxesQueryHandler : IRequestHandler<GetAllTaxesQuery, List<TaxDto>>
        {
            private readonly TaxRepository _repository;

            public GetAllTaxesQueryHandler(TaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<TaxDto>> Handle(GetAllTaxesQuery request, CancellationToken cancellationToken)
            {
                var taxes = await _repository.GetAllTaxesAsync(request.CompanyId);
                return taxes.Select(MapperTax.MapToTax).ToList();
            }
        }

        public class GetAllTaxesQueryValidator : AbstractValidator<GetAllTaxesQuery>
        {
            public GetAllTaxesQueryValidator()
            {
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}