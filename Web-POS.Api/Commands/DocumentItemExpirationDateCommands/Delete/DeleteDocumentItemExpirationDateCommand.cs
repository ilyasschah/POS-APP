using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.DocumentItemExpirationDateCommands.Delete
{
    public class DeleteDocumentItemExpirationDateCommand : IRequest<bool>
    {
        public int DocumentItemId { get; set; }
        public int CompanyId { get; set; }

        public DeleteDocumentItemExpirationDateCommand(int documentItemId, int companyId)
        {
            DocumentItemId = documentItemId;
            CompanyId = companyId;
        }

        public class DeleteDocumentItemExpirationDateCommandHandler : IRequestHandler<DeleteDocumentItemExpirationDateCommand, bool>
        {
            private readonly DocumentItemExpirationDateService _service;

            public DeleteDocumentItemExpirationDateCommandHandler(DocumentItemExpirationDateService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteDocumentItemExpirationDateCommand request, CancellationToken cancellationToken)
            {
                return await _service.Delete(request.DocumentItemId, request.CompanyId);
            }
        }

        public class DeleteDocumentItemExpirationDateCommandValidator : AbstractValidator<DeleteDocumentItemExpirationDateCommand>
        {
            public DeleteDocumentItemExpirationDateCommandValidator()
            {
                RuleFor(c => c.DocumentItemId).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}