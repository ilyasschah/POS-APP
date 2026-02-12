using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;


namespace Products.Api.Commands.BarcodesCommands.Add
{
    public class AddBarcodecommand: IRequest<bool>
    {
        public CreateBarcodeRequest Request { get; set; }
        public AddBarcodecommand(CreateBarcodeRequest createBarcodeRequest)
        {
            Request = createBarcodeRequest;
        }
        public class AddBarcodecommandHandler : IRequestHandler<AddBarcodecommand, bool>
        {
            private readonly BarcodeService _barcodeService;
            public AddBarcodecommandHandler(BarcodeService barcodeService)
            {
                _barcodeService = barcodeService;
            }
            public Task<bool> Handle(AddBarcodecommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return _barcodeService.Create(request.Request.Value, request.Request.ProductId);
                }
                catch (Exception)
                {
                    throw;
                }
            }
            public class AddBarcodecommandValidator : AbstractValidator<AddBarcodecommand>
            {
                public AddBarcodecommandValidator()
                {
                    RuleFor(o => o.Request.Value).NotNull().NotEmpty().WithMessage("mut not be null.");
                    RuleFor(pid => pid.Request.ProductId).NotNull().NotEmpty().WithMessage("product ID must be entred ");
                }
            }
        }
    }
}
