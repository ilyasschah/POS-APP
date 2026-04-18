using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.KitchenQuery
{
    public class KitchenOrderResponseDto
    {
        public PosOrderDto Order { get; set; }
        public List<PosOrderItemDto> Items { get; set; }
    }

    public class GetKitchenOrdersQuery : IRequest<List<KitchenOrderResponseDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetKitchenOrdersQueryHandler : IRequestHandler<GetKitchenOrdersQuery, List<KitchenOrderResponseDto>>
    {
        private readonly PosOrderRepository _orderRepo;
        private readonly PosOrderItemRepository _itemRepo;

        public GetKitchenOrdersQueryHandler(PosOrderRepository orderRepo, PosOrderItemRepository itemRepo)
        {
            _orderRepo = orderRepo;
            _itemRepo = itemRepo;
        }

        public async Task<List<KitchenOrderResponseDto>> Handle(GetKitchenOrdersQuery request, CancellationToken cancellationToken)
        {
            var result = new List<KitchenOrderResponseDto>();

            var allOrders = await _orderRepo.GetAllAsync(request.CompanyId);
            var activeOrders = allOrders.Where(o => o.ServiceStatus == 1).OrderBy(o => o.Id).ToList();

            foreach (var order in activeOrders)
            {
                var items = await _itemRepo.GetByPosOrderIdAsync(order.Id, request.CompanyId);

                result.Add(new KitchenOrderResponseDto
                {
                    Order = MapperPosOrder.MapToPosOrderDto(order),
                    Items = items.Select(MapperPosOrderItem.MapToPosOrderItemDto).ToList()
                });
            }

            return result;
        }
    }
}