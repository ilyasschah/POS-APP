using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Queries.BarCodesQuery.Get
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
