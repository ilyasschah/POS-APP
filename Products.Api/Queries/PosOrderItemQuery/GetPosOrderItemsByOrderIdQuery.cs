using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosOrderItemQuery
{
    public class GetPosOrderItemsByOrderIdQuery : IRequest<IEnumerable<PosOrderItemDto>>
    {
        public int PosOrderId { get; set; }
    }
    public class GetPosOrderItemsByOrderIdQueryHandler : IRequestHandler<GetPosOrderItemsByOrderIdQuery, IEnumerable<PosOrderItemDto>>
    {
        private readonly PosOrderItemRepository _repository;

        public GetPosOrderItemsByOrderIdQueryHandler(PosOrderItemRepository repository)
        {
            _repository = repository;
        }
        public async Task<IEnumerable<PosOrderItemDto>> Handle(GetPosOrderItemsByOrderIdQuery request, CancellationToken cancellationToken)
        {
            var items = await _repository.GetByOrderIdAsync(request.PosOrderId);
            return items.Select(MapperPosOrderItem.MapToPosOrderItemDto).ToList();
        }
    }
}