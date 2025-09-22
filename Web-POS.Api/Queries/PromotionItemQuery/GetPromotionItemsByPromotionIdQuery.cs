using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PromotionItemQuery
{
    public class GetPromotionItemsByPromotionIdQuery : IRequest<List<PromotionItemDto>>
    {
        public int PromotionId { get; set; }

        public class GetPromotionItemsByPromotionIdQueryHandler : IRequestHandler<GetPromotionItemsByPromotionIdQuery, List<PromotionItemDto>>
        {
            private readonly PromotionItemRepository _repository;

            public GetPromotionItemsByPromotionIdQueryHandler(PromotionItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PromotionItemDto>> Handle(GetPromotionItemsByPromotionIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByPromotionIdAsync(request.PromotionId);
                return entities.Select(MapperPromotionItem.MapToPromotionItemDto).ToList();
            }
        }
    }
}