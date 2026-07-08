using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.StartingCashQuery
{
    public class GetAllStartingCashQuery : IRequest<List<StartingCashDto>>
    {
        public int CompanyId { get; set; }

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
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperStartingCash.MapToStartingCashDto).ToList();
            }
        }
    }
}
