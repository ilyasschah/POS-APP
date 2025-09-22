using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.DocumentItemTaxCommands.Update
{
    public class UpdateDocumentitemtaxamountcommand : IRequest<bool>
    {
        public UpdateDocumentItemTaxRequest Request { get; }

        public UpdateDocumentitemtaxamountcommand(UpdateDocumentItemTaxRequest request)
        {
            Request = request;
        }
        public class UpdateDocumentitemtaxamountcommandHandler : IRequestHandler<UpdateDocumentitemtaxamountcommand, bool>
        {
            private readonly DocumentItemTaxService _service;

            public UpdateDocumentitemtaxamountcommandHandler(DocumentItemTaxService service)
            {
                _service = service;
            }
            public Task<bool> Handle(UpdateDocumentitemtaxamountcommand command, CancellationToken cancellationToken)
            {
                try
                {
                    return _service.Update(command.Request.Amount , command.Request.DocumentItemId);
                }
                catch (Exception)
                {

                    throw;
                }

            }
        }

        public class UpdateDocumentCommandValidator : AbstractValidator<UpdateDocumentitemtaxamountcommand>
        {
            public UpdateDocumentCommandValidator()
            {
                //RuleFor(c => c.Id).GreaterThan(0); rkia
                RuleFor(c => c.Request.Amount).NotEmpty();
            }
        }
    }
}

