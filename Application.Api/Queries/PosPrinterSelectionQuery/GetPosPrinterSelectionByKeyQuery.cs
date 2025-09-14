using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosPrinterSelectionQuery
{
    public class GetPosPrinterSelectionByKeyQuery : IRequest<PosPrinterSelectionDto?>
    {
        public string Key { get; set; } = default!;

        public class GetPosPrinterSelectionByKeyQueryHandler
            : IRequestHandler<GetPosPrinterSelectionByKeyQuery, PosPrinterSelectionDto?>
        {
            private readonly PosPrinterSelectionRepository _repository;

            public GetPosPrinterSelectionByKeyQueryHandler(PosPrinterSelectionRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosPrinterSelectionDto?> Handle(GetPosPrinterSelectionByKeyQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByKeyAsync(request.Key);
                return entity == null ? null : MapperPosPrinterSelection.MapToPosPrinterSelectionDto(entity);
            }
        }
    }
}
