using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PromotionQuery
{
    public class GetAllPromotionsQuery : IRequest<List<PromotionDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllPromotionsQueryHandler : IRequestHandler<GetAllPromotionsQuery, List<PromotionDto>>
        {
            private readonly PromotionRepository _repository;

            public GetAllPromotionsQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PromotionDto>> Handle(GetAllPromotionsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperPromotion.MapToPromotionDto).ToList();
            }
        }
    }
}