using Documents.Api.Models;
using Documents.Api.Services;
using FluentValidation;
using MediatR;
using Products.Api.Commands.BarcodesCommands.Update;

namespace Documents.Api.Commands.DocumentItemExpirationDateCommands.Update
{
    public class UpdateDocumentItemExpirationDateCommand : IRequest<bool>
    {
        public UpdateDocumentItemExpirationDateRequest Request { get; set; }
        //public int DocumentItemId { get; set; }
        //public DateTime NewExpirationDate { get; set; }
        public UpdateDocumentItemExpirationDateCommand(UpdateDocumentItemExpirationDateRequest request)
        {
            Request = request;
        }
        public class UpdateDocumentItemExpirationDateCommandHandler : IRequestHandler<UpdateDocumentItemExpirationDateCommand, bool>
        {
            private readonly DocumentItemExpirationDateService _documentItemExpirationDateService;
            public UpdateDocumentItemExpirationDateCommandHandler(DocumentItemExpirationDateService documentItemExpirationDateService)
            {
                _documentItemExpirationDateService = documentItemExpirationDateService;
            }
            public async Task<bool> Handle(UpdateDocumentItemExpirationDateCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return await _documentItemExpirationDateService.UpdateByDocumentItemId(request.Request.DocumentItemId, request.Request.ExpirationDate);
                }
                catch (Exception)
                {
                    throw;
                }
            }
            public class UpdateDocumentItemExpirationDateCommandValidator : AbstractValidator<UpdateDocumentItemExpirationDateCommand>
            {
                public UpdateDocumentItemExpirationDateCommandValidator()
                {
                    RuleFor(o => o.Request.ExpirationDate).NotNull().NotEmpty().WithMessage("Expiration Date mut not be null.");
                    RuleFor(pid => pid.Request.DocumentItemId).NotNull().NotEmpty().WithMessage("Document Item ID must be entred ");
                }
            }
        }
    }
}
