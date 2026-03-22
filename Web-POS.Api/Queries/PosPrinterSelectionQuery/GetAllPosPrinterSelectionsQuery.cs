using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosPrinterSelectionQuery
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
