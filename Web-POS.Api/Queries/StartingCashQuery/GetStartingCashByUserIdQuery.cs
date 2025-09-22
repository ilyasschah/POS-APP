using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.StartingCashQuery
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
