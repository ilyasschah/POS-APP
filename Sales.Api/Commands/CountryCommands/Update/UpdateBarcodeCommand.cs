//using MediatR;
//using Sales.Api.Repository;

//namespace Sales.Api.Commands.CountryCommands.Update
//{
//    public class UpdateBarcodeByValuecommand : IRequest<bool>
//    {
//        public required string BarcodeValue { get; set; }
//        public required string NewBarcodeValue { get; set; }
//        public class UpdateBarcodeByProductNamecommandHandler : IRequestHandler<UpdateBarcodeByValuecommand, bool>
//        {
//            private readonly CustomerRepository _barcodeRepository;
//            public UpdateBarcodeByProductNamecommandHandler(
//                CustomerRepository barcodeRepository)
//            {
//                _barcodeRepository = barcodeRepository;
//            }
//            public async Task<bool> Handle(UpdateBarcodeByValuecommand request, CancellationToken cancellationToken)
//            {
//                var barcode = await _barcodeRepository.GetByValueAsync(request.BarcodeValue);
//                if (barcode == null) return false;

//                //Update the value
//                barcode.UpdateValue(request.NewBarcodeValue);
//                await _barcodeRepository.UpdateAsync(barcode);
//                return true;
//            }
//        }
//    }
//}
