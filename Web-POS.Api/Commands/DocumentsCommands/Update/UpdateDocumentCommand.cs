using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentsCommands.Update
{
    public class UpdateDocumentCommand : IRequest<bool>
    {
        public UpdateDocumentRequest Request { get; }
        public int CompanyId { get; }

        public UpdateDocumentCommand(UpdateDocumentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateDocumentCommandHandler : IRequestHandler<UpdateDocumentCommand, bool>
        {
            private readonly DocumentService _service;

            public UpdateDocumentCommandHandler(DocumentService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdateDocumentCommand command, CancellationToken cancellationToken)
            {
                return await _service.UpdateAsync(command.Request, command.CompanyId);
            }
        }

        public class UpdateDocumentCommandValidator : AbstractValidator<UpdateDocumentCommand>
        {
            public UpdateDocumentCommandValidator()
            {
                RuleFor(c => c.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");

                RuleFor(c => c.Request.Id)
                    .GreaterThan(0).WithMessage("Document ID is required to perform an update.");

                RuleFor(c => c.Request.Number)
                    .NotEmpty().WithMessage("Document Number cannot be empty if provided.")
                    .When(c => c.Request.Number != null);

                RuleFor(c => c.Request.Total)
                    .GreaterThanOrEqualTo(0).WithMessage("Total cannot be negative.")
                    .When(c => c.Request.Total.HasValue);
            }
        }
    }
}