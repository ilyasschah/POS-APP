using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PromotionItemQuery
{
    public class GetPromotionItemByIdQuery : IRequest<PromotionItemDto?>
    {
        public int Id { get; set; }
        public int companyId { get; set; }

        public class GetPromotionItemByIdQueryHandler : IRequestHandler<GetPromotionItemByIdQuery, PromotionItemDto?>
        {
            private readonly PromotionItemRepository _repository;

            public GetPromotionItemByIdQueryHandler(PromotionItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<PromotionItemDto?> Handle(GetPromotionItemByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetItemByIdAsync(request.Id, request.companyId);
                return entity == null ? null : MapperPromotionItem.MapToDto(entity);
            }
        }
    }
}