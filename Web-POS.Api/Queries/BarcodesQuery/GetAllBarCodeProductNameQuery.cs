using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.BarcodesQuery
{
    public class GetAllBarCodeProductNameQuery : IRequest<List<BarcodeDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllBarCodeProductNameQueryHandler : IRequestHandler<GetAllBarCodeProductNameQuery, List<BarcodeDto>>
        {
            private readonly BarcodeRepository _repository;

            public GetAllBarCodeProductNameQueryHandler(BarcodeRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<BarcodeDto>> Handle(GetAllBarCodeProductNameQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetProductsNamesBarcodesAsync(request.CompanyId);
                return entities.Select(MapperBarcode.MapToBarcodeDto).ToList();
            }
        }
    }
}