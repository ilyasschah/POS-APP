using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.DocumentsCommands.Delete
{
    public class DeleteDocumentCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }

        public DeleteDocumentCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteDocumentCommandHandler : IRequestHandler<DeleteDocumentCommand, bool>
        {
            private readonly DocumentService _service;

            public DeleteDocumentCommandHandler(DocumentService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteDocumentCommand command, CancellationToken cancellationToken)
            {
                return await _service.DeleteAsync(command.Id, command.CompanyId);
            }
        }

        public class DeleteDocumentCommandValidator : AbstractValidator<DeleteDocumentCommand>
        {
            public DeleteDocumentCommandValidator()
            {
                RuleFor(c => c.Id)
                    .GreaterThan(0).WithMessage("Document ID must be valid to delete.");

                RuleFor(c => c.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}