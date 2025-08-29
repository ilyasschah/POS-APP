using Documents.Api.Models.DocumentTypes;
using Documents.Api.Services;
using FluentValidation;
using MediatR;

namespace Documents.Api.Commands.DocumentTypeCommands.Add
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
                try
                {
                    return _service.Create(command.Request);
                }
                catch (Exception)
                {

                    throw;
                }
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
