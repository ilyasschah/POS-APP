using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.StartingCashQuery
{
    public class GetStartingCashByUserIdQuery : IRequest<List<StartingCashDto>>
    {
        public int UserId { get; set; }

        public class GetStartingCashByUserIdQueryHandler : IRequestHandler<GetStartingCashByUserIdQuery, List<StartingCashDto>>
        {
            private readonly StartingCashRepository _repository;

            public GetStartingCashByUserIdQueryHandler(StartingCashRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<StartingCashDto>> Handle(GetStartingCashByUserIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByUserIdAsync(request.UserId);
                return entities.Select(MapperStartingCash.MapToStartingCashDto).ToList();
            }
        }
    }
}