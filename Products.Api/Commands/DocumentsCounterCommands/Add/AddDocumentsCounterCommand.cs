using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.DocumentsCounterCommands.Add
{
    public class AddDocumentsCounterCommand : IRequest<DocumentsCounterDto>
    {
        public CreateDocumentsCounterRequest Request { get; }

        public AddDocumentsCounterCommand(CreateDocumentsCounterRequest request)
        {
            Request = request;
        }

        public class AddDocumentsCounterCommandHandler : IRequestHandler<AddDocumentsCounterCommand, DocumentsCounterDto>
        {
            private readonly DocumentsCounterService _service;

            public AddDocumentsCounterCommandHandler(DocumentsCounterService service)
            {
                _service = service;
            }

            public async Task<DocumentsCounterDto> Handle(AddDocumentsCounterCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperDocumentsCounter.MapToDocumentsCounterDto(newEntity);
            }
        }

        public class AddDocumentsCounterCommandValidator : AbstractValidator<AddDocumentsCounterCommand>
        {
            public AddDocumentsCounterCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty();
                RuleFor(c => c.Request.Value).GreaterThanOrEqualTo(0);
            }
        }
    }
}