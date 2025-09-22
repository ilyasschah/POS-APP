using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PromotionQuery
{
    public class GetAllPromotionsQuery : IRequest<List<PromotionDto>>
    {
        public class GetAllPromotionsQueryHandler : IRequestHandler<GetAllPromotionsQuery, List<PromotionDto>>
        {
            private readonly PromotionRepository _repository;

            public GetAllPromotionsQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PromotionDto>> Handle(GetAllPromotionsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperPromotion.MapToPromotionDto).ToList();
            }
        }
    }
}