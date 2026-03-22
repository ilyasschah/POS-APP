using Api.Commands.DocumentItemCommands.Add;
using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentItemTaxCommands.Add
{
    public class AddDocumentItemtaxCommand : IRequest<bool>
    {
        public CreateDocumentItemTaxRequest Request { get; set; }
        public AddDocumentItemtaxCommand(CreateDocumentItemTaxRequest createDocumentItemTaxRequest)
        {
            Request = createDocumentItemTaxRequest;
        }
        public class AddDocumentItemtaxCommandHandler : IRequestHandler<AddDocumentItemtaxCommand, bool>
        {
            private readonly DocumentItemTaxService _documentItemTaxService;
            public AddDocumentItemtaxCommandHandler(DocumentItemTaxService documentItemTaxService)
            {
                _documentItemTaxService = documentItemTaxService;
            }
            public Task<bool> Handle(AddDocumentItemtaxCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return _documentItemTaxService.Create(request.Request);
                }
                catch (Exception)
                {
                    throw;
                }
            }
            public class AddDocumentItemCommandValidator : AbstractValidator<AddDocumentItemtaxCommand>
            {
                public AddDocumentItemCommandValidator()
                {
                    RuleFor(o => o.Request.DocumentItemId).NotNull().NotEmpty().WithMessage("document ID must not be null.");
                    RuleFor(pid => pid.Request.TaxId).NotNull().NotEmpty().WithMessage("product IDmust not be null");
                }
            }

        }
    }
}
