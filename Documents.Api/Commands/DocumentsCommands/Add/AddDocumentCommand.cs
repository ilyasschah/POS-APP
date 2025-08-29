using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Services;
using FluentValidation;
using MediatR;

namespace Documents.Api.Commands.DocumentCommands.Add
{
    public class AddDocumentCommand : IRequest<DocumentDto>
    {
        public CreateDocumentRequest Request { get; }

        public AddDocumentCommand(CreateDocumentRequest request)
        {
            Request = request;
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
                var newEntity = await _service.Create(command.Request);
                return MapperDocument.MapToDocumentDto(newEntity);
            }
        }

        public class AddDocumentCommandValidator : AbstractValidator<AddDocumentCommand>
        {
            public AddDocumentCommandValidator()
            {
                RuleFor(c => c.Request.Number).NotEmpty();
                RuleFor(c => c.Request.UserId).GreaterThan(0);
                RuleFor(c => c.Request.DocumentTypeId).GreaterThan(0);
                RuleFor(c => c.Request.WarehouseId).GreaterThan(0);
                RuleFor(c => c.Request.Total).GreaterThanOrEqualTo(0);
            }
        }
    }
}