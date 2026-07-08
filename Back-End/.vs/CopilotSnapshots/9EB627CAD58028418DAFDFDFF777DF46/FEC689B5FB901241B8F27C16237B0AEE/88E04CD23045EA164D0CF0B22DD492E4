using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.StartingCashQuery
{
    public class GetAllStartingCashQuery : IRequest<List<StartingCashDto>>
    {
        public class GetAllStartingCashQueryHandler
            : IRequestHandler<GetAllStartingCashQuery, List<StartingCashDto>>
        {
            private readonly StartingCashRepository _repository;

            public GetAllStartingCashQueryHandler(StartingCashRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<StartingCashDto>> Handle(GetAllStartingCashQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperStartingCash.MapToStartingCashDto).ToList();
            }
        }
    }
}
