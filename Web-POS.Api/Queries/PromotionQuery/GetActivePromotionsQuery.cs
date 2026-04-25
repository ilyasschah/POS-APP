using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.PromotionQuery
{
    public class GetActivePromotionsQuery : IRequest<List<PromotionDto>>
    {
        public int CompanyId { get; set; }

        public class GetActivePromotionsQueryHandler : IRequestHandler<GetActivePromotionsQuery, List<PromotionDto>>
        {
            private readonly PromotionRepository _repository;
            public GetActivePromotionsQueryHandler(PromotionRepository repository) => _repository = repository;

            public async Task<List<PromotionDto>> Handle(GetActivePromotionsQuery request, CancellationToken cancellationToken)
            {
                var promotions = await _repository.GetActivePromotionsAsync(request.CompanyId);
                var items = await _repository.GetItemsByPromotionIdsAsync(promotions.Select(p => p.Id).ToList(), request.CompanyId);

                return promotions.Select(p => MapperPromotion.MapToDto(p, items.Where(i => i.PromotionId == p.Id).ToList())).ToList();
            }
        }
    }
}