using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosPrinterSelectionSettingsQuery
{
    public class GetAllPosPrinterSelectionSettingsQuery : IRequest<List<PosPrinterSelectionSettingsDto>>
    {
        public class GetAllPosPrinterSelectionSettingsQueryHandler
            : IRequestHandler<GetAllPosPrinterSelectionSettingsQuery, List<PosPrinterSelectionSettingsDto>>
        {
            private readonly PosPrinterSelectionSettingsRepository _repository;

            public GetAllPosPrinterSelectionSettingsQueryHandler(PosPrinterSelectionSettingsRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosPrinterSelectionSettingsDto>> Handle(GetAllPosPrinterSelectionSettingsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperPosPrinterSelectionSettings.MapToPosPrinterSelectionSettingsDto).ToList();
            }
        }
    }
}
