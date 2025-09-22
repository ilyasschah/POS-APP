// FILE: Products.Api.Queries\LoyaltyCardQuery\GetAllLoyaltyCardsQuery.cs

using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.LoyaltyCardQuery;

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
