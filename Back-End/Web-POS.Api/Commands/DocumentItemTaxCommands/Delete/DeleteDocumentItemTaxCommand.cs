using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.DocumentItemTaxCommands.Delete
{
    public class DeleteDocumentItemTaxCommand : IRequest<bool>
    {
        public int DocumentItemId { get; set; }
        public int TaxId { get; set; }
        public int CompanyId { get; set; }

        public DeleteDocumentItemTaxCommand(int documentItemId, int taxId, int companyId)
        {
            DocumentItemId = documentItemId;
            TaxId = taxId;
            CompanyId = companyId;
        }

        public class DeleteDocumentItemTaxCommandHandler : IRequestHandler<DeleteDocumentItemTaxCommand, bool>
        {
            private readonly DocumentItemTaxService _service;

            public DeleteDocumentItemTaxCommandHandler(DocumentItemTaxService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteDocumentItemTaxCommand request, CancellationToken cancellationToken)
            {
                return await _service.Delete(request.DocumentItemId, request.TaxId, request.CompanyId);
            }
        }

        public class DeleteDocumentItemTaxCommandValidator : AbstractValidator<DeleteDocumentItemTaxCommand>
        {
            public DeleteDocumentItemTaxCommandValidator()
            {
                RuleFor(c => c.DocumentItemId).GreaterThan(0);
                RuleFor(c => c.TaxId).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}