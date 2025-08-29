// FILE: Sales.Api.Queries\LoyaltyCardQuery\GetAllLoyaltyCardsQuery.cs

using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.LoyaltyCardQuery;

public class GetAllLoyaltyCardsQuery : IRequest<List<LoyaltyCardDto>>
{
    public class GetAllLoyaltyCardsQueryHandler : IRequestHandler<GetAllLoyaltyCardsQuery, List<LoyaltyCardDto>>
    {
        private readonly LoyaltyCardRepository _repository;

        public GetAllLoyaltyCardsQueryHandler(LoyaltyCardRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<LoyaltyCardDto>> Handle(GetAllLoyaltyCardsQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync();
            return entities.Select(MapperLoyaltyCard.MapToLoyaltyCardDto).ToList();
        }
    }
}
