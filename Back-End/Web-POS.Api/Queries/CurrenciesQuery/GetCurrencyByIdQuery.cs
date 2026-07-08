using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;
using FluentValidation;

namespace Api.Queries.CurrenciesQuery
{
    public class GetCurrencyByIdQuery : IRequest<CurrencyDto?>
    {
        public int Id { get; set; }

        public class GetCurrencyByIdHandler : IRequestHandler<GetCurrencyByIdQuery, CurrencyDto?>
        {
            private readonly CurrencyRepository _repository;

            public GetCurrencyByIdHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<CurrencyDto?> Handle(GetCurrencyByIdQuery request, CancellationToken cancellationToken)
            {
                var currency = await _repository.GetByIdAsync(request.Id);
                return currency == null ? null : MapperCurrency.MapToCurrencyDto(currency);
            }
        }
    }
    public class GetCurrencyByIdQueryValidator : AbstractValidator<GetCurrencyByIdQuery>
    {
        public GetCurrencyByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Currency ID must be valid.");
        }
    }
}