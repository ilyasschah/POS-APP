using MediatR;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PosOrderQuery
{
    public class GetKitchenOrdersQuery : IRequest<List<KitchenOrderDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetKitchenOrdersQueryHandler : IRequestHandler<GetKitchenOrdersQuery, List<KitchenOrderDto>>
    {
        private readonly PosOrderRepository _orderRepo;
        private readonly PosOrderItemRepository _itemRepo;

        public GetKitchenOrdersQueryHandler(PosOrderRepository orderRepo, PosOrderItemRepository itemRepo)
        {
            _orderRepo = orderRepo;
            _itemRepo = itemRepo;
        }

        public async Task<List<KitchenOrderDto>> Handle(GetKitchenOrdersQuery request, CancellationToken cancellationToken)
        {
            // Fetch only orders where ServiceStatus == 2 (In Preparation)
            var allOrders = await _orderRepo.GetAllAsync(request.CompanyId);
            var kitchenOrders = allOrders
                .Where(o => o.ServiceStatus == 2)
                .OrderBy(o => o.Id)
                .ToList();

            var result = new List<KitchenOrderDto>();

            foreach (var order in kitchenOrders)
            {
                var items = await _itemRepo.GetByPosOrderIdAsync(order.Id, request.CompanyId);

                // Resolve table name if this order is linked to a table
                string? tableName = null;
                if (order.FloorPlanTableId.HasValue)
                {
                    var table = await _orderRepo.GetFloorPlanTableAsync(order.FloorPlanTableId.Value, request.CompanyId);
                    tableName = table?.Name;
                }

                result.Add(new KitchenOrderDto
                {
                    Id = order.Id,
                    Number = order.Number,
                    FloorPlanTableId = order.FloorPlanTableId,
                    TableName = tableName,
                    ServiceType = order.ServiceType,
                    ServiceStatus = order.ServiceStatus,
                    Items = items.Select(i => new KitchenOrderItemDto
                    {
                        Id = i.Id,
                        ProductName = i.Product?.Name ?? "Unknown",
                        Quantity = i.Quantity,
                        Comment = i.Comment,
                    }).ToList()
                });
            }

            return result;
        }
    }
}