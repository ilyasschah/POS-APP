using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;


namespace Products.Api.Commands.BarcodesCommands.Update
{
    public class UpdateBarcodecommand : IRequest<BarcodeDto>
    {
        public UpdateBarcodeRequest Request { get; set; }
        public int CompanyId { get; }
        public UpdateBarcodecommand(UpdateBarcodeRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }
        public class UpdateBarcodeByProductNamecommandHandler : IRequestHandler<UpdateBarcodecommand, BarcodeDto>
        {
            private readonly BarcodeService _barcodeservice;
            public UpdateBarcodeByProductNamecommandHandler(BarcodeService barcodeservice)
            {
                _barcodeservice = barcodeservice;
            }
            public async Task<BarcodeDto> Handle(UpdateBarcodecommand request, CancellationToken cancellationToken)
            {
                var updatedEntity = await _barcodeservice.Update(request.Request, request.CompanyId);
                return updatedEntity;
            }
            public class UpdateBarcodecommandValidator : AbstractValidator<UpdateBarcodecommand>
            {
                public UpdateBarcodecommandValidator()
                {
                    RuleFor(bcv => bcv.Request.NewBarcodeValue).NotNull().NotEmpty().WithMessage("Barcode must not be null.");
                }
            }
        }
    }
}
