using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;

namespace Products.Api.Queries.PosPrinterSettingsQuery
{
    public class GetPosPrinterSettingsByPrinterNameQuery : IRequest<PosPrinterSettingsDto?>
    {
        public string PrinterName { get; set; } = default!;

        public class GetPosPrinterSettingsByPrinterNameQueryHandler
            : IRequestHandler<GetPosPrinterSettingsByPrinterNameQuery, PosPrinterSettingsDto?>
        {
            private readonly PosPrinterSettingsRepository _repository;

            public GetPosPrinterSettingsByPrinterNameQueryHandler(PosPrinterSettingsRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosPrinterSettingsDto?> Handle(GetPosPrinterSettingsByPrinterNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByPrinterNameAsync(request.PrinterName);
                return entity == null ? null : MapperPosPrinterSettings.MapToPosPrinterSettingsDto(entity);
            }
        }
    }
}
