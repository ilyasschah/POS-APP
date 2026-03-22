using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.DocumentItemTaxCommands.Delete
{
    public class DeleteDocumentItemTaxCommand : IRequest<bool>
    {
        public int Id { get; }
        public DeleteDocumentItemTaxCommand(int id)
        {
            Id = id;
        }
        public class DeleteDocumentItemTaxCommandHandler : IRequestHandler<DeleteDocumentItemTaxCommand, bool>
        {
            private readonly DocumentItemTaxService _service;
            public DeleteDocumentItemTaxCommandHandler(DocumentItemTaxService service)
            {
                _service = service;
            }
            public Task<bool> Handle(DeleteDocumentItemTaxCommand request, CancellationToken cancellationToken)
            {
                return _service.Delete(request.Id);
            }
        }
        public class DeleteDocumentItemTaxCommandValidator : AbstractValidator<DeleteDocumentItemTaxCommand>
        {
            public DeleteDocumentItemTaxCommandValidator()
            {
                RuleFor(o => o.Id).NotNull().NotEmpty().WithMessage("Document Item Tax ID must not be null.");
            }
        }

    }
}
