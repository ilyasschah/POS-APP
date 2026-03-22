using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.TaxesQuery.Get
{
    public class GetTaxByIdQuery : IRequest<TaxDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetTaxByIdQueryHandler : IRequestHandler<GetTaxByIdQuery, TaxDto?>
        {
            private readonly TaxRepository _repository;

            public GetTaxByIdQueryHandler(TaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<TaxDto?> Handle(GetTaxByIdQuery request, CancellationToken cancellationToken)
            {
                var tax = await _repository.GetTaxByIdAsync(request.Id, request.CompanyId);
                return tax == null ? null : MapperTax.MapToTaxDto(tax);
            }
        }

        public class GetTaxByIdQueryValidator : AbstractValidator<GetTaxByIdQuery>
        {
            public GetTaxByIdQueryValidator()
            {
                RuleFor(x => x.Id).GreaterThan(0).WithMessage("Tax ID must be valid.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}