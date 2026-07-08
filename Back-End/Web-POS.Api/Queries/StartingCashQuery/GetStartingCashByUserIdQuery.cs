using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.StartingCashQuery
{
    public class GetStartingCashByUserIdQuery : IRequest<List<StartingCashDto>>
    {
        public int UserId { get; set; }

        public class GetStartingCashByUserIdQueryHandler
            : IRequestHandler<GetStartingCashByUserIdQuery, List<StartingCashDto>>
        {
            private readonly StartingCashRepository _repository;

            public GetStartingCashByUserIdQueryHandler(StartingCashRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<StartingCashDto>> Handle(GetStartingCashByUserIdQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetByUserIdAsync(request.UserId);
                return list.Select(MapperStartingCash.MapToStartingCashDto).ToList();
            }
        }
    }
}
