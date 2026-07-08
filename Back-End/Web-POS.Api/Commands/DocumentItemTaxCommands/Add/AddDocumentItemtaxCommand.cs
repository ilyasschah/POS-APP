using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.DocumentItemTaxCommands.Add
{
    public class AddDocumentItemTaxCommand : IRequest<DocumentItemTaxDto>
    {
        public CreateDocumentItemTaxRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddDocumentItemTaxCommand(CreateDocumentItemTaxRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddDocumentItemTaxCommandHandler : IRequestHandler<AddDocumentItemTaxCommand, DocumentItemTaxDto>
        {
            private readonly DocumentItemTaxService _service;

            public AddDocumentItemTaxCommandHandler(DocumentItemTaxService service)
            {
                _service = service;
            }

            public async Task<DocumentItemTaxDto> Handle(AddDocumentItemTaxCommand request, CancellationToken cancellationToken)
            {
                return await _service.Create(request.Request, request.CompanyId);
            }
        }

        public class AddDocumentItemTaxCommandValidator : AbstractValidator<AddDocumentItemTaxCommand>
        {
            public AddDocumentItemTaxCommandValidator()
            {
                RuleFor(c => c.Request.DocumentItemId).GreaterThan(0);
                RuleFor(c => c.Request.TaxId).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}