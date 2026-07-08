using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.CurrenciesQuery
{
    public class GetAllCurrencyQuery : IRequest<List<CurrencyDto>>
    {
        public class GetAllCurrencyHandler : IRequestHandler<GetAllCurrencyQuery, List<CurrencyDto>>
        {
            private readonly CurrencyRepository _repository;

            public GetAllCurrencyHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<CurrencyDto>> Handle(GetAllCurrencyQuery request, CancellationToken cancellationToken)
            {
                var currencies = await _repository.GetAllAsync();
                return currencies.Select(MapperCurrency.MapToCurrencyDto).ToList();
            }
        }
    }
}