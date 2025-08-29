using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.StartingCashQuery
{
    public class GetAllStartingCashQuery : IRequest<List<StartingCashDto>>
    {
        public class GetAllStartingCashQueryHandler : IRequestHandler<GetAllStartingCashQuery, List<StartingCashDto>>
        {
            private readonly StartingCashRepository _repository;

            public GetAllStartingCashQueryHandler(StartingCashRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<StartingCashDto>> Handle(GetAllStartingCashQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperStartingCash.MapToStartingCashDto).ToList();
            }
        }
    }
}