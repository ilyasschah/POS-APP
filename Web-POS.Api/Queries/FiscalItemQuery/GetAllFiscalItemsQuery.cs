using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.FiscalItemQuery
{
    public class GetAllFiscalItemsQuery : IRequest<List<FiscalItemDto>>
    {
        public class GetAllFiscalItemsQueryHandler : IRequestHandler<GetAllFiscalItemsQuery, List<FiscalItemDto>>
        {
            private readonly FiscalItemRepository _repository;

            public GetAllFiscalItemsQueryHandler(FiscalItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<FiscalItemDto>> Handle(GetAllFiscalItemsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperFiscalItem.MapToFiscalItemDto).ToList();
            }
        }
    }
}