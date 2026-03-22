using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
namespace Api.Queries.BarcodesQuery.Get
{
    public class GetAllBarCodeProductNameQuery : IRequest<List<BarcodeDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllBarCodeProductNameQueryHandler : IRequestHandler<GetAllBarCodeProductNameQuery, List<BarcodeDto>>
        {
            private readonly BarcodeRepository _barcodeRepository;
            public GetAllBarCodeProductNameQueryHandler(BarcodeRepository barcodeRepository)
            {
                _barcodeRepository = barcodeRepository;
            }
            public async Task<List<BarcodeDto>> Handle(GetAllBarCodeProductNameQuery request, CancellationToken cancellationToken)
            {
                var barcode = await _barcodeRepository.GetProductsNamesBarcodesAsync(request.CompanyId);
                return barcode.Select(MapperBarcode_ProductName.MapBarCodes).ToList();
            }
        }
    }
}
