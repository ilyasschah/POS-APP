using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosOrderItemQuery
{
    public class GetAllPosOrderItemsQuery : IRequest<List<PosOrderItemDto>>
    {
        public class GetAllPosOrderItemsQueryHandler : IRequestHandler<GetAllPosOrderItemsQuery, List<PosOrderItemDto>>
        {
            private readonly PosOrderItemRepository _repository;

            public GetAllPosOrderItemsQueryHandler(PosOrderItemRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<PosOrderItemDto>> Handle(GetAllPosOrderItemsQuery request, CancellationToken cancellationToken)
            {
                var items = await _repository.GetAllAsync();
                return items.Select(MapperPosOrderItem.MapToPosOrderItemDto).ToList();
            }
        }
    }
}