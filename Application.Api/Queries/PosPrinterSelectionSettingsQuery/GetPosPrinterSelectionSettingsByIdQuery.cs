using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosPrinterSelectionSettingsQuery
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
