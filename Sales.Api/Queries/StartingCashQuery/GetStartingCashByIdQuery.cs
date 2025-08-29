using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.StartingCashQuery
{
    public class GetStartingCashByIdQuery : IRequest<StartingCashDto?>
    {
        public int Id { get; set; }

        public class GetStartingCashByIdQueryHandler : IRequestHandler<GetStartingCashByIdQuery, StartingCashDto?>
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