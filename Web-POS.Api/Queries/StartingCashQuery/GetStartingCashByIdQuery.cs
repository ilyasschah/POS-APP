using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.StartingCashQuery
{
    public class GetStartingCashByIdQuery : IRequest<StartingCashDto?>
    {
        public int Id { get; set; }

        public class GetStartingCashByIdQueryHandler
            : IRequestHandler<GetStartingCashByIdQuery, StartingCashDto?>
        {
            private readonly StartingCashRepository _repository;

            public GetStartingCashByIdQueryHandler(StartingCashRepository repository)
            {
                _repository = repository;
            }

            public async Task<StartingCashDto?> Handle(GetStartingCashByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperStartingCash.MapToStartingCashDto(entity);
            }
        }
    }
}
