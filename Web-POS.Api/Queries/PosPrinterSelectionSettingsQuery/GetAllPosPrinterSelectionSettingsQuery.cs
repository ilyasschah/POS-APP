using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PosPrinterSelectionSettingsQuery
{
    public class GetAllPosPrinterSelectionSettingsQuery : IRequest<List<PosPrinterSelectionSettingsDto>>
    {
        public int CompanyId { get; set; }

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
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperPosPrinterSelectionSettings.MapToPosPrinterSelectionSettingsDto).ToList();
            }
        }
    }
}
