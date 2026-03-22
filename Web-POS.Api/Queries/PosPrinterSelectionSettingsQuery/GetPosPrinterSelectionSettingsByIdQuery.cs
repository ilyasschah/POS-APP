using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PosPrinterSelectionSettingsQuery
{
    public class GetPosPrinterSelectionSettingsByIdQuery : IRequest<PosPrinterSelectionSettingsDto?>
    {
        public int Id { get; set; }

        public class GetPosPrinterSelectionSettingsByIdQueryHandler
            : IRequestHandler<GetPosPrinterSelectionSettingsByIdQuery, PosPrinterSelectionSettingsDto?>
        {
            private readonly PosPrinterSelectionSettingsRepository _repository;

            public GetPosPrinterSelectionSettingsByIdQueryHandler(PosPrinterSelectionSettingsRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosPrinterSelectionSettingsDto?> Handle(GetPosPrinterSelectionSettingsByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPosPrinterSelectionSettings.MapToPosPrinterSelectionSettingsDto(entity);
            }
        }
    }
}
