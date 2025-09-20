using FluentValidation;
using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Products.Api.Services;
using Products.Api.Models;

namespace Products.Api.Commands.DocumentsCounterCommands.Update
{
    public class UpdateDocumentsCounterCommand : IRequest<bool>
    {
        public string Name { get; }
        public UpdateDocumentsCounterRequest Request { get; }

        public UpdateDocumentsCounterCommand(string name, UpdateDocumentsCounterRequest request)
        {
            Name = name;
            Request = request;
        }

        public class UpdateDocumentsCounterCommandHandler : IRequestHandler<UpdateDocumentsCounterCommand, bool>
        {
            private readonly DocumentsCounterService _service;

            public UpdateDocumentsCounterCommandHandler(DocumentsCounterService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateDocumentsCounterCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Name, command.Request);
            }
        }

        public class UpdateDocumentsCounterCommandValidator : AbstractValidator<UpdateDocumentsCounterCommand>
        {
            public UpdateDocumentsCounterCommandValidator()
            {
                RuleFor(c => c.Name).NotEmpty();
                RuleFor(c => c.Request.Value).GreaterThanOrEqualTo(0);
            }
        }
    }
}