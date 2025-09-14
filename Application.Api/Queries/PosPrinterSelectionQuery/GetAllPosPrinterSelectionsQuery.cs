using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosPrinterSelectionQuery
{
    public class GetAllPosPrinterSelectionsQuery : IRequest<List<PosPrinterSelectionDto>>
    {
        public class GetAllPosPrinterSelectionsQueryHandler
            : IRequestHandler<GetAllPosPrinterSelectionsQuery, List<PosPrinterSelectionDto>>
        {
            private readonly PosPrinterSelectionRepository _repository;

            public GetAllPosPrinterSelectionsQueryHandler(PosPrinterSelectionRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosPrinterSelectionDto>> Handle(GetAllPosPrinterSelectionsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperPosPrinterSelection.MapToPosPrinterSelectionDto).ToList();
            }
        }
    }
}
