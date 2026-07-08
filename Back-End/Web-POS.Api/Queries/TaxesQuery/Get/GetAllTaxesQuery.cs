using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.TaxesQuery.Get
{
    public class GetAllTaxesQuery : IRequest<List<TaxDto>>
    {
        public int CompanyId { get; set; }
        public DateTime? ModifiedAfter { get; set; }

        public class GetAllTaxesQueryHandler : IRequestHandler<GetAllTaxesQuery, List<TaxDto>>
        {
            private readonly TaxRepository _repository;

            public GetAllTaxesQueryHandler(TaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<TaxDto>> Handle(GetAllTaxesQuery request, CancellationToken cancellationToken)
            {
                var taxes = await _repository.GetAllTaxesAsync(request.CompanyId, request.ModifiedAfter);
                return taxes.Select(MapperTax.MapToTaxDto).ToList();
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