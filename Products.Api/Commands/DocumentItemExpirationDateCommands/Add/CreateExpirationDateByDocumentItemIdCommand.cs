using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.DocumentItemExpirationDateCommands.Add
{
    public class CreateExpirationDateByDocumentItemIdCommand : IRequest<bool>
    {
        public CreateDocumentItemExpirationDateRequest Request { get; set; }
        public CreateExpirationDateByDocumentItemIdCommand(CreateDocumentItemExpirationDateRequest request)
        {
            Request = request;
        }
        public class CreateByDocumentItemIdCommandHandler : IRequestHandler<CreateExpirationDateByDocumentItemIdCommand, bool>
        {
            private readonly DocumentItemExpirationDateService _documentItemExpirationDateService;
            public CreateByDocumentItemIdCommandHandler(DocumentItemExpirationDateService documentItemExpirationDateService)
            {
                _documentItemExpirationDateService = documentItemExpirationDateService;
            }
            public async Task<bool> Handle(CreateExpirationDateByDocumentItemIdCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return await _documentItemExpirationDateService.CreateByDocumentItemId(request.Request.DocumentItemId, request.Request.ExpirationDate);
                }
                catch (Exception)
                {
                    throw;
                }
            }
            public class CreateByDocumentItemIdValidator : AbstractValidator<CreateExpirationDateByDocumentItemIdCommand>
            {
                public CreateByDocumentItemIdValidator()
                {
                    RuleFor(o => o.Request.ExpirationDate).NotNull().NotEmpty().WithMessage("Expiration Date mut not be null.");
                    RuleFor(pid => pid.Request.DocumentItemId).NotNull().NotEmpty().WithMessage("Document Item ID must be entred ");
                }
            }
        }
    }
}
