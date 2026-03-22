using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentsCommands.Update
{
    public class UpdateDocumentCommand : IRequest<bool>
    {
        public UpdateDocumentRequest Request { get; }
        public int CompanyId { get; }

        public UpdateDocumentCommand(UpdateDocumentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }
        public class UpdateDocumentCommandHandler : IRequestHandler<UpdateDocumentCommand, bool>
        {
            private readonly DocumentService _service;

            public UpdateDocumentCommandHandler(DocumentService service)
            {
                _service = service;
            }
            public Task<bool> Handle(UpdateDocumentCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Request.Id, command.Request, command.CompanyId);
            }
        }

        public class UpdateDocumentCommandValidator : AbstractValidator<UpdateDocumentCommand>
        {
            public UpdateDocumentCommandValidator()
            {
                //RuleFor(c => c.Id).GreaterThan(0); rkia
                RuleFor(c => c.Request.Number).NotEmpty();
                RuleFor(c => c.Request.Total).GreaterThanOrEqualTo(0);
            }
        }
    }
}