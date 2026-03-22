using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PromotionItemQuery
{
    public class GetAllPromotionItemsQuery : IRequest<List<PromotionItemDto>>
    {
        public class GetAllPromotionItemsQueryHandler : IRequestHandler<GetAllPromotionItemsQuery, List<PromotionItemDto>>
        {
            private readonly PromotionItemRepository _repository;

            public GetAllPromotionItemsQueryHandler(PromotionItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PromotionItemDto>> Handle(GetAllPromotionItemsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperPromotionItem.MapToPromotionItemDto).ToList();
            }
        }
    }
}