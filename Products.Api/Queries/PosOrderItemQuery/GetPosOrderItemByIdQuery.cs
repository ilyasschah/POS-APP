using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosOrderItemQuery
{
    public record GetPosOrderItemByIdQuery(int Id) : IRequest<PosOrderItemDto>;
    public class GetPosOrderItemByIdQueryHandler : IRequestHandler<GetPosOrderItemByIdQuery, PosOrderItemDto>
    {
        private readonly PosOrderItemRepository _repository;
        public GetPosOrderItemByIdQueryHandler(PosOrderItemRepository repository)
        {
            _repository = repository;
        }
        public async Task<PosOrderItemDto> Handle(GetPosOrderItemByIdQuery request, CancellationToken cancellationToken)
        {
            var item = await _repository.GetByIdAsync(request.Id);
            return MapperPosOrderItem.MapToPosOrderItemDto(item);
        }
    }
}