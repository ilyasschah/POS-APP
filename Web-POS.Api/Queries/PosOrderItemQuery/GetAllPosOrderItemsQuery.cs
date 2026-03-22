using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PosOrderItemQuery
{
    public class GetAllPosOrderItemsQuery : IRequest<List<PosOrderItemDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllPosOrderItemsQueryHandler : IRequestHandler<GetAllPosOrderItemsQuery, List<PosOrderItemDto>>
        {
            private readonly PosOrderItemRepository _repository;

            public GetAllPosOrderItemsQueryHandler(PosOrderItemRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<PosOrderItemDto>> Handle(GetAllPosOrderItemsQuery request, CancellationToken cancellationToken)
            {
                var items = await _repository.GetAllAsync(request.CompanyId);
                return items.Select(MapperPosOrderItem.MapToPosOrderItemDto).ToList();
            }
        }
    }
}