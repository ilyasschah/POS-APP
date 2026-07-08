using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.CurrenciesQuery
{
    public class GetCurrencyByNameQuery : IRequest<CurrencyDto?>
    {
        public string Name { get; set; } = default!;

        public class GetCurrencyByNameQueryHandler : IRequestHandler<GetCurrencyByNameQuery, CurrencyDto?>
        {
            private readonly CurrencyRepository _repository;

            public GetCurrencyByNameQueryHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<CurrencyDto?> Handle(GetCurrencyByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperCurrency.MapToCurrencyDto(entity);
            }
        }
    }
}
