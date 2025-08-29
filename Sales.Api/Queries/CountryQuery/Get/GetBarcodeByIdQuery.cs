//using MediatR;
//using Sales.Api.Models;
//using Sales.Api.Repository;
//namespace Sales.Api.Queries.CountryQuery.Get
//{
//    public class GetBarcodeByIdQuery : IRequest<CustomerDto?>
//    {
//        public int Id { get; set; }

//        public GetBarcodeByIdQuery(int id)
//        {
//            Id = id;
//        }
//    }
//    public class GetBarcodeByIdQueryHandler : IRequestHandler<GetBarcodeByIdQuery, CustomerDto?>
//    {
//         private readonly CustomerRepository _barcodeRepository;

//         public GetBarcodeByIdQueryHandler(CustomerRepository barcodeRepository)
//         {
//             _barcodeRepository = barcodeRepository;
//         }
//         public async Task<CustomerDto?> Handle(GetBarcodeByIdQuery request, CancellationToken cancellationToken)
//         {
//            var barcode = await _barcodeRepository.GetBarCodeByIdQuery(request.Id);
//            if (barcode is null)
//            {
//                return null;
//            }
//            return new CustomerDto
//            {
//                Value = barcode.Value,
//                ProductName = barcode.Product.Name // This requires the Product to be loaded
//            };
//            //var barcode = await _barcodeRepository.GetBarCodeByIdQuery();                       ask rkia
//            //return barcode.Select(MapperBarcode.MapBarCodes).Tolist();

//         }
//    }
//}