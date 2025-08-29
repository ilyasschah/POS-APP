using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Queries.CurrenciesQuery.Get
{
    public class GetAllCurrenciesQuery : IRequest<List<CurrencyDto>>
    {
        public class GetAllCurrenciesQueryHandler : IRequestHandler<GetAllCurrenciesQuery, List<CurrencyDto>>
        {
            private readonly CurrencyRepository _currencyRepository;
            public GetAllCurrenciesQueryHandler(CurrencyRepository currencyRepository)
            {
                _currencyRepository = currencyRepository;
            }
            public async Task<List<CurrencyDto>> Handle(GetAllCurrenciesQuery request, CancellationToken cancellationToken)
            {
                var currencies = await _currencyRepository.GetCurrenciesAsync();
                return currencies.Select(MapperCurrency.MapToCurrency).ToList();
            }
        }
    }
}
