using Api.Commands.DocumentItemCommands.Add;
using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.DocumentItemCommands.Delete
{
    public class DeleteDocumentItemCommand : IRequest<bool>
    {
        public int Id { get; }
        public DeleteDocumentItemCommand(int id)
        {
            Id = id;
        }
        public class DeleteDocumentItemCommandHandler : IRequestHandler<DeleteDocumentItemCommand, bool>
        {
            private readonly DocumentItemService _service;
            public DeleteDocumentItemCommandHandler(DocumentItemService service)
            {
                _service = service;
            }
            public Task<bool> Handle(DeleteDocumentItemCommand request, CancellationToken cancellationToken)
            {
                return _service.Delete(request.Id);
            }
        }
        public class AddDocumentItemCommandValidator : AbstractValidator<DeleteDocumentItemCommand>
        {
            public AddDocumentItemCommandValidator()
            {
                RuleFor(pid => pid.Id).NotNull().NotEmpty().WithMessage("Docuemtn item ID must not be null");
            }
        }
    }
}

