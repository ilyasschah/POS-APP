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

        public GetKitchenOrdersQueryHandler(PosOrderRepository orderRepo)
        {
            _orderRepo = orderRepo;
        }

        public async Task<List<KitchenOrderDto>> Handle(GetKitchenOrdersQuery request, CancellationToken cancellationToken)
        {
            return await _orderRepo.GetKitchenOrdersAsync(request.CompanyId);
        }
    }
}