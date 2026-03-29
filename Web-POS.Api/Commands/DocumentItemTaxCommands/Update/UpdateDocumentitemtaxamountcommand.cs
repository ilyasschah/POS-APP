using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.DocumentItemTaxCommands.Update
{
    public class UpdateDocumentItemTaxCommand : IRequest<DocumentItemTaxDto>
    {
        public UpdateDocumentItemTaxRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdateDocumentItemTaxCommand(UpdateDocumentItemTaxRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateDocumentItemTaxCommandHandler : IRequestHandler<UpdateDocumentItemTaxCommand, DocumentItemTaxDto>
        {
            private readonly DocumentItemTaxService _service;

            public UpdateDocumentItemTaxCommandHandler(DocumentItemTaxService service)
            {
                _service = service;
            }

            public async Task<DocumentItemTaxDto> Handle(UpdateDocumentItemTaxCommand request, CancellationToken cancellationToken)
            {
                return await _service.Update(request.Request, request.CompanyId);
            }
        }

        public class UpdateDocumentItemTaxCommandValidator : AbstractValidator<UpdateDocumentItemTaxCommand>
        {
            public UpdateDocumentItemTaxCommandValidator()
            {
                RuleFor(c => c.Request.DocumentItemId).GreaterThan(0);
                RuleFor(c => c.Request.TaxId).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}