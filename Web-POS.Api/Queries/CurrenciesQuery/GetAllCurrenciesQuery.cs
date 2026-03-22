using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.CurrenciesQuery
{
    public class GetAllCurrenciesQuery : IRequest<List<CurrencyDto>>
    {
        public class GetAllCurrenciesQueryHandler : IRequestHandler<GetAllCurrenciesQuery, List<CurrencyDto>>
        {
            private readonly CurrencyRepository _repository;

            public GetAllCurrenciesQueryHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<CurrencyDto>> Handle(GetAllCurrenciesQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperCurrency.MapToCurrencyDto).ToList();
            }
        }
    }
}
