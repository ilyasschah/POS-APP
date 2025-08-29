using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.FiscalItemQuery
{
    public class GetFiscalItemByPluQuery : IRequest<FiscalItemDto?>
    {
        public int PLU { get; set; }

        public class GetFiscalItemByPluQueryHandler : IRequestHandler<GetFiscalItemByPluQuery, FiscalItemDto?>
        {
            private readonly FiscalItemRepository _repository;

            public GetFiscalItemByPluQueryHandler(FiscalItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<FiscalItemDto?> Handle(GetFiscalItemByPluQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByPluAsync(request.PLU);
                return entity == null ? null : MapperFiscalItem.MapToFiscalItemDto(entity);
            }
        }
    }
}