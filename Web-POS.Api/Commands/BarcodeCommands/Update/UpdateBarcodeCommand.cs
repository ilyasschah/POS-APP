using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.BarcodeCommands.Update
{
    public class UpdateBarcodecommand : IRequest<BarcodeDto>
    {
        public UpdateBarcodeRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdateBarcodecommand(UpdateBarcodeRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateBarcodecommandHandler : IRequestHandler<UpdateBarcodecommand, BarcodeDto>
        {
            private readonly BarcodeService _service;

            public UpdateBarcodecommandHandler(BarcodeService service)
            {
                _service = service;
            }

            public async Task<BarcodeDto> Handle(UpdateBarcodecommand request, CancellationToken cancellationToken)
            {
                return await _service.Update(request.Request, request.CompanyId);
            }
        }

        public class UpdateBarcodecommandValidator : AbstractValidator<UpdateBarcodecommand>
        {
            public UpdateBarcodecommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0);
                RuleFor(c => c.Request.Value).NotEmpty();
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}