using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.BarcodesCommands.Delete
{
    public class DeleteBarcodeByIdCommand : IRequest<bool>
    {
        public DeleteBarcodeRequest Request { get; set; }
        public int CompanyId { get; }
        public DeleteBarcodeByIdCommand(DeleteBarcodeRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }
        public class DeleteBarcodeByIdCommandHandler : IRequestHandler<DeleteBarcodeByIdCommand, bool>
        {
            private readonly BarcodeService _barcodeService;
            public DeleteBarcodeByIdCommandHandler(BarcodeService barcodeService)
            {
                _barcodeService = barcodeService;
            }
            public async Task<bool> Handle(DeleteBarcodeByIdCommand request, CancellationToken cancellationToken)
            {
                var result = await _barcodeService.Delete(request.Request, request.CompanyId);
                return result;
            }
            public class DeleteBarcodeByIdCommandValidator : AbstractValidator<DeleteBarcodeByIdCommand>
            {
                public DeleteBarcodeByIdCommandValidator()
                {
                    RuleFor(bcv => bcv.Request.Value).NotNull().NotEmpty().WithMessage("Barcode must not be null.");
                }
            }
        }
    }
}