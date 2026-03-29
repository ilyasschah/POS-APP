using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentsCommands.Add
{
    public class AddDocumentCommand : IRequest<DocumentDto>
    {
        public CreateDocumentRequest Request { get; }
        public int CompanyId { get; }

        public AddDocumentCommand(CreateDocumentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddDocumentCommandHandler : IRequestHandler<AddDocumentCommand, DocumentDto>
        {
            private readonly DocumentService _service;

            public AddDocumentCommandHandler(DocumentService service)
            {
                _service = service;
            }

            public async Task<DocumentDto> Handle(AddDocumentCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }

        public class AddDocumentCommandValidator : AbstractValidator<AddDocumentCommand>
        {
            public AddDocumentCommandValidator()
            {
                RuleFor(c => c.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");

                RuleFor(c => c.Request.Number)
                    .NotEmpty().WithMessage("Document Number is required.");

                RuleFor(c => c.Request.UserId)
                    .GreaterThan(0).WithMessage("User ID must be valid.");

                RuleFor(c => c.Request.DocumentTypeId)
                    .GreaterThan(0).WithMessage("Document Type ID must be valid.");

                RuleFor(c => c.Request.WarehouseId)
                    .GreaterThan(0).WithMessage("Warehouse ID must be valid.");

                RuleFor(c => c.Request.Total)
                    .GreaterThanOrEqualTo(0).WithMessage("Total cannot be negative.");
            }
        }
    }
}