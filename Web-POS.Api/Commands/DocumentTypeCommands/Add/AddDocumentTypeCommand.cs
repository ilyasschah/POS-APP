using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentTypeCommands.Add
{
    public class AddDocumentTypeCommand(CreateDocumentTypeRequest createdocumenttypeRequest) : IRequest<bool>
    {
        public CreateDocumentTypeRequest Request { get; set; } = createdocumenttypeRequest;
        public class AddDocumentTypeCommandHandler : IRequestHandler<AddDocumentTypeCommand, bool>
        {
            private readonly DocumentTypeService _service;

            public AddDocumentTypeCommandHandler(DocumentTypeService service) => _service = service;

            public Task<bool> Handle(AddDocumentTypeCommand command, CancellationToken cancellationToken)
            {
                return _service.Create(command.Request);

            }
        }

        public class AddDocumentTypeValidator : AbstractValidator<AddDocumentTypeCommand>
        {
            public AddDocumentTypeValidator()
            {
                RuleFor(x => x.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(x => x.Request.Code).NotEmpty().MaximumLength(50);
                RuleFor(x => x.Request.DocumentCategoryId).GreaterThan(0);
                RuleFor(x => x.Request.WarehouseId).GreaterThan(0);
            }
        }
    }
}
