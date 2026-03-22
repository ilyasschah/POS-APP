using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.CurrenciesQuery
{
    public class GetCurrencyByIdQuery : IRequest<CurrencyDto?>
    {
        public int Id { get; set; }

        public class GetCurrencyByIdQueryHandler : IRequestHandler<GetCurrencyByIdQuery, CurrencyDto?>
        {
            private readonly CurrencyRepository _repository;

            public GetCurrencyByIdQueryHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<CurrencyDto?> Handle(GetCurrencyByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperCurrency.MapToCurrencyDto(entity);
            }
        }
    }
}
