using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.BarcodeCommands.Add
{
    public class AddBarcodecommand : IRequest<BarcodeDto>
    {
        public CreateBarcodeRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddBarcodecommand(CreateBarcodeRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddBarcodecommandHandler : IRequestHandler<AddBarcodecommand, BarcodeDto>
        {
            private readonly BarcodeService _service;

            public AddBarcodecommandHandler(BarcodeService service)
            {
                _service = service;
            }

            public async Task<BarcodeDto> Handle(AddBarcodecommand request, CancellationToken cancellationToken)
            {
                return await _service.Create(request.Request, request.CompanyId);
            }
        }

        public class AddBarcodecommandValidator : AbstractValidator<AddBarcodecommand>
        {
            public AddBarcodecommandValidator()
            {
                RuleFor(c => c.Request.ProductId).GreaterThan(0);
                RuleFor(c => c.Request.Value).NotEmpty();
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}