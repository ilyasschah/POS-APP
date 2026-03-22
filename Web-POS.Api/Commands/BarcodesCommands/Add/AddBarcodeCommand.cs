using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;


namespace Api.Commands.BarcodesCommands.Add
{
    public class AddBarcodecommand: IRequest<BarcodeDto>
    {
        public CreateBarcodeRequest Request { get; set; }
        public int CompanyId { get; }
        public AddBarcodecommand(CreateBarcodeRequest createBarcodeRequest, int companyId)
        {
            Request = createBarcodeRequest;
            CompanyId = companyId;
        }
        public class AddBarcodecommandHandler : IRequestHandler<AddBarcodecommand, BarcodeDto>
        {
            private readonly BarcodeService _barcodeService;
            public AddBarcodecommandHandler(BarcodeService barcodeService)
            {
                _barcodeService = barcodeService;
            }
            public async Task<BarcodeDto> Handle(AddBarcodecommand request, CancellationToken cancellationToken)
            {
                var newEntity = await _barcodeService.Create(request.Request , request.CompanyId);
                return newEntity;
            }
            public class AddBarcodecommandValidator : AbstractValidator<AddBarcodecommand>
            {
                public AddBarcodecommandValidator()
                {
                    RuleFor(o => o.Request.Value).NotNull().NotEmpty().WithMessage("Barcode must not be null.");
                    RuleFor(pid => pid.Request.ProductId).NotNull().NotEmpty().WithMessage("product ID must be entered.");
                }
            }
        }
    }
}
