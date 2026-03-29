using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.DocumentItemExpirationDateCommands.Add
{
    public class AddDocumentItemExpirationDateCommand : IRequest<DocumentItemExpirationDateDto>
    {
        public CreateDocumentItemExpirationDateRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddDocumentItemExpirationDateCommand(CreateDocumentItemExpirationDateRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddDocumentItemExpirationDateCommandHandler : IRequestHandler<AddDocumentItemExpirationDateCommand, DocumentItemExpirationDateDto>
        {
            private readonly DocumentItemExpirationDateService _service;

            public AddDocumentItemExpirationDateCommandHandler(DocumentItemExpirationDateService service)
            {
                _service = service;
            }

            public async Task<DocumentItemExpirationDateDto> Handle(AddDocumentItemExpirationDateCommand request, CancellationToken cancellationToken)
            {
                return await _service.Create(request.Request, request.CompanyId);
            }
        }

        public class AddDocumentItemExpirationDateCommandValidator : AbstractValidator<AddDocumentItemExpirationDateCommand>
        {
            public AddDocumentItemExpirationDateCommandValidator()
            {
                RuleFor(c => c.Request.DocumentItemId).GreaterThan(0);
                RuleFor(c => c.Request.ExpirationDate).NotEmpty();
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}