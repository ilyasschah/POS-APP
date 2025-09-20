using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosPrinterSelectionQuery
{
    public class GetPosPrinterSelectionByIdQuery : IRequest<PosPrinterSelectionDto?>
    {
        public int Id { get; set; }

        public class GetPosPrinterSelectionByIdQueryHandler
            : IRequestHandler<GetPosPrinterSelectionByIdQuery, PosPrinterSelectionDto?>
        {
            private readonly PosPrinterSelectionRepository _repository;

            public GetPosPrinterSelectionByIdQueryHandler(PosPrinterSelectionRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosPrinterSelectionDto?> Handle(GetPosPrinterSelectionByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPosPrinterSelection.MapToPosPrinterSelectionDto(entity);
            }
        }
    }
}
