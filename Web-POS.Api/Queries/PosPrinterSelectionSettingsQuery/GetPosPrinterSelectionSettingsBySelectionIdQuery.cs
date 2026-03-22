using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PosPrinterSelectionSettingsQuery
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
