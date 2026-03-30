using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.BarcodesQuery
{
    public class GetBarcodesByProductIdQuery : IRequest<List<BarcodeDto>>
    {
        public int ProductId { get; set; }
        public int CompanyId { get; set; }

        public class GetBarcodesByProductIdQueryHandler : IRequestHandler<GetBarcodesByProductIdQuery, List<BarcodeDto>>
        {
            private readonly BarcodeRepository _repository;

            public GetBarcodesByProductIdQueryHandler(BarcodeRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<BarcodeDto>> Handle(GetBarcodesByProductIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByProductIdAsync(request.ProductId, request.CompanyId);
                return entities.Select(MapperBarcode.MapToBarcodeDto).ToList();
            }
        }
    }
}