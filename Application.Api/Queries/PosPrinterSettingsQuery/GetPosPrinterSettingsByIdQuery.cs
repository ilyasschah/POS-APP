using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;
namespace Products.Api.Queries.PosPrinterSettingsQuery
{
    public class GetPosPrinterSettingsByIdQuery : IRequest<PosPrinterSettingsDto?>
    {
        public int Id { get; set; }

        public class GetPosPrinterSettingsByIdQueryHandler
            : IRequestHandler<GetPosPrinterSettingsByIdQuery, PosPrinterSettingsDto?>
        {
            private readonly PosPrinterSettingsRepository _repository;

            public GetPosPrinterSettingsByIdQueryHandler(PosPrinterSettingsRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosPrinterSettingsDto?> Handle(GetPosPrinterSettingsByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPosPrinterSettings.MapToPosPrinterSettingsDto(entity);
            }
        }
    }
}
