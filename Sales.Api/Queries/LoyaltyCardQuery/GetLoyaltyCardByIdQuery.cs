// FILE: Sales.Api.Queries\LoyaltyCardQuery\GetLoyaltyCardByIdQuery.cs

using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.LoyaltyCardQuery;

public class GetLoyaltyCardByIdQuery : IRequest<LoyaltyCardDto?>
{
    public int Id { get; }
    public GetLoyaltyCardByIdQuery(int id) { Id = id; }

    public class GetLoyaltyCardByIdQueryHandler : IRequestHandler<GetLoyaltyCardByIdQuery, LoyaltyCardDto?>
    {
        private readonly LoyaltyCardRepository _repository;

        public GetLoyaltyCardByIdQueryHandler(LoyaltyCardRepository repository)
        {
            _repository = repository;
        }

        public async Task<LoyaltyCardDto?> Handle(GetLoyaltyCardByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id);
            return entity == null ? null : MapperLoyaltyCard.MapToLoyaltyCardDto(entity);
        }
    }
}
