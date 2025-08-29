using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PromotionItemQuery
{
    public class GetPromotionItemByIdQuery : IRequest<PromotionItemDto?>
    {
        public int Id { get; set; }

        public class GetPromotionItemByIdQueryHandler : IRequestHandler<GetPromotionItemByIdQuery, PromotionItemDto?>
        {
            private readonly PromotionItemRepository _repository;

            public GetPromotionItemByIdQueryHandler(PromotionItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<PromotionItemDto?> Handle(GetPromotionItemByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPromotionItem.MapToPromotionItemDto(entity);
            }
        }
    }
}