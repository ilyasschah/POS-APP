using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosPrinterSelectionSettingsQuery
{
    public class GetPosPrinterSelectionSettingsBySelectionIdQuery : IRequest<List<PosPrinterSelectionSettingsDto>>
    {
        public int PosPrinterSelectionId { get; set; }

        public class GetPosPrinterSelectionSettingsBySelectionIdQueryHandler
            : IRequestHandler<GetPosPrinterSelectionSettingsBySelectionIdQuery, List<PosPrinterSelectionSettingsDto>>
        {
            private readonly PosPrinterSelectionSettingsRepository _repository;

            public GetPosPrinterSelectionSettingsBySelectionIdQueryHandler(PosPrinterSelectionSettingsRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosPrinterSelectionSettingsDto>> Handle(GetPosPrinterSelectionSettingsBySelectionIdQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetBySelectionIdAsync(request.PosPrinterSelectionId);
                return list.Select(MapperPosPrinterSelectionSettings.MapToPosPrinterSelectionSettingsDto).ToList();
            }
        }
    }
}
