using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;

namespace Products.Api.Queries.PosPrinterSettingsQuery
{
    public class GetAllPosPrinterSettingsQuery : IRequest<List<PosPrinterSettingsDto>>
    {
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
                var list = await _repository.GetAllAsync();
                return list.Select(MapperPosPrinterSettings.MapToPosPrinterSettingsDto).ToList();
            }
        }
    }
}
