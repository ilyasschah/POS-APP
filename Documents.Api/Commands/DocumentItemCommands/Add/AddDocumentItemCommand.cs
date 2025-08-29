using Documents.Api.Models;
using Documents.Api.Services;
using FluentValidation;
using MediatR;

namespace Documents.Api.Commands.DocumentItemCommands.Add
{
    public class AddDocumentItemCommand : IRequest<bool>
    {
        public CreateDocumentItemRequest Request { get; set; }
        public AddDocumentItemCommand (CreateDocumentItemRequest createDocumentItemRequest)
        {
            Request = createDocumentItemRequest;
        }
        public class AddDocumentItemCommandHandler : IRequestHandler<AddDocumentItemCommand,bool>
        {
            private readonly DocumentItemService _documentItemService;
            public AddDocumentItemCommandHandler(DocumentItemService documentItemService)
            {
                _documentItemService = documentItemService;
            }
            public Task<bool> Handle (AddDocumentItemCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return _documentItemService.Create(request.Request);
                }
                catch (Exception)
                {

                    throw;
                }
            }
            public class AddDocumentItemCommandValidator : AbstractValidator<AddDocumentItemCommand>
            {
                public AddDocumentItemCommandValidator()
                {
                    RuleFor(o => o.Request.DocumentId).NotNull().NotEmpty().WithMessage("document ID must not be null.");
                    RuleFor(pid => pid.Request.ProductId).NotNull().NotEmpty().WithMessage("product IDmust not be null");
                }
            }
        }
    }
}
