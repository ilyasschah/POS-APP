// FILE: Products.Api.Queries\LoyaltyCardQuery\GetLoyaltyCardsByCompanyQuery.cs

using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.LoyaltyCardQuery;

public class GetLoyaltyCardsByCompanyQuery : IRequest<List<LoyaltyCardDto>>
{
    public int CompanyId { get; }

    public GetLoyaltyCardsByCompanyQuery(int companyId)
    {
        CompanyId = companyId;
    }

    public class Handler : IRequestHandler<GetLoyaltyCardsByCompanyQuery, List<LoyaltyCardDto>>
    {
        private readonly LoyaltyCardRepository _repository;

        public Handler(LoyaltyCardRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<LoyaltyCardDto>> Handle(
            GetLoyaltyCardsByCompanyQuery request,
            CancellationToken cancellationToken)
        {
            var entities = await _repository.GetByCompanyIdAsync(request.CompanyId);
            return entities.Select(MapperLoyaltyCard.MapToLoyaltyCardDto).ToList();
        }
    }
}
