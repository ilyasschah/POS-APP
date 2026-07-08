using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Repository;

namespace Api.Queries.PosPrinterSettingsQuery
{
    public class GetAllPosPrinterSettingsQuery : IRequest<List<PosPrinterSettingsDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllPosPrinterSettingsQueryHandler
            : IRequestHandler<GetAllPosPrinterSettingsQuery, List<PosPrinterSettingsDto>>
        {
            private readonly PosPrinterSettingsRepository _repository;

            public GetAllPosPrinterSettingsQueryHandler(PosPrinterSettingsRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosPrinterSettingsDto>> Handle(GetAllPosPrinterSettingsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperPosPrinterSettings.MapToPosPrinterSettingsDto).ToList();
            }
        }
    }
}
