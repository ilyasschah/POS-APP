using MediatR;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Queries.BarCodesQuery.Get
{
    public class GetBarcodeByIdQuery : IRequest<BarcodeDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public GetBarcodeByIdQuery(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }
    }
    public class GetBarcodeByIdQueryHandler : IRequestHandler<GetBarcodeByIdQuery, BarcodeDto?>
    {
         private readonly BarcodeRepository _barcodeRepository;

         public GetBarcodeByIdQueryHandler(BarcodeRepository barcodeRepository)
         {
             _barcodeRepository = barcodeRepository;
         }
         public async Task<BarcodeDto?> Handle(GetBarcodeByIdQuery request, CancellationToken cancellationToken)
         {
            var barcode = await _barcodeRepository.GetBarCodeByIdQuery(request.Id, request.CompanyId);
            if (barcode is null)
            {
                return null;
            }
            return new BarcodeDto
            {
                Id = barcode.Id,
                Value = barcode.Value,
                ProductId = barcode.ProductId,
                ProductName = barcode.Product.Name,
                CompanyId = barcode.CompanyId,
                CompanyName = barcode.Company.Name
            };
         }
    }
}