using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.DocumentItemExpirationDateCommands.Update
{
    public class UpdateDocumentItemExpirationDateCommand : IRequest<DocumentItemExpirationDateDto>
    {
        public UpdateDocumentItemExpirationDateRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdateDocumentItemExpirationDateCommand(UpdateDocumentItemExpirationDateRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateDocumentItemExpirationDateCommandHandler : IRequestHandler<UpdateDocumentItemExpirationDateCommand, DocumentItemExpirationDateDto>
        {
            private readonly DocumentItemExpirationDateService _service;

            public UpdateDocumentItemExpirationDateCommandHandler(DocumentItemExpirationDateService service)
            {
                _service = service;
            }

            public async Task<DocumentItemExpirationDateDto> Handle(UpdateDocumentItemExpirationDateCommand request, CancellationToken cancellationToken)
            {
                return await _service.Update(request.Request, request.CompanyId);
            }
        }

        public class UpdateDocumentItemExpirationDateCommandValidator : AbstractValidator<UpdateDocumentItemExpirationDateCommand>
        {
            public UpdateDocumentItemExpirationDateCommandValidator()
            {
                RuleFor(c => c.Request.DocumentItemId).GreaterThan(0);
                RuleFor(c => c.Request.ExpirationDate).NotEmpty();
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}