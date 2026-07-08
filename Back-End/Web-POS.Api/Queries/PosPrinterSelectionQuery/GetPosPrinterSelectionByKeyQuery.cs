using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosPrinterSelectionQuery
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
