using Documents.Api.Models.DocumentTypes;
using Documents.Api.Services;
using MediatR;
using FluentValidation;

namespace Documents.Api.Commands.DocumentTypeCommands.Update
{
    public record UpdateDocumentTypeCommand(int Id, UpdateDocumentTypeRequest Request) : IRequest<bool>;

    public class UpdateDocumentTypeHandler : IRequestHandler<UpdateDocumentTypeCommand, bool>
    {
        private readonly DocumentTypeService _service;

        public UpdateDocumentTypeHandler(DocumentTypeService service) => _service = service;

        public async Task<bool> Handle(UpdateDocumentTypeCommand command, CancellationToken cancellationToken)
        {
            return await _service.Update(command.Id, command.Request);
        }
    }

    public class UpdateDocumentTypeValidator : AbstractValidator<UpdateDocumentTypeCommand>
    {
        public UpdateDocumentTypeValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0);
            RuleFor(x => x.Request.Name).NotEmpty().MaximumLength(255);
            RuleFor(x => x.Request.Code).NotEmpty().MaximumLength(50);
            RuleFor(x => x.Request.DocumentCategoryId).GreaterThan(0);
            RuleFor(x => x.Request.WarehouseId).GreaterThan(0);
        }
    }
}
