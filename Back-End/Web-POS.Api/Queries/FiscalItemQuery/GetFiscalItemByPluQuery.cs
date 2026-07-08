using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.FiscalItemQuery
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