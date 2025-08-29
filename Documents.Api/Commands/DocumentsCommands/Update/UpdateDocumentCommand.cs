using Documents.Api.Models;
using Documents.Api.Services;
using FluentValidation;
using MediatR;

namespace Documents.Api.Commands.DocumentCommands.Update
{
    public class UpdateDocumentCommand : IRequest<bool>
    {
        public UpdateDocumentRequest Request { get; }

        public UpdateDocumentCommand(UpdateDocumentRequest request)
        {
            Request = request;
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
                try
                {
                    return _service.Update(command.Request.Id , command.Request);
                }
                catch (Exception)
                {

                    throw;
                }
                
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