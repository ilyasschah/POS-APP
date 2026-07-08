using FluentValidation;
using MediatR;
using Api.Models;

namespace Api.Commands.PosPrinterSelectionCommands.Update
{
    public class UpdatePosPrinterSelectionCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePosPrinterSelectionRequest Request { get; }

        public UpdatePosPrinterSelectionCommand(int id, UpdatePosPrinterSelectionRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdatePosPrinterSelectionCommandHandler
            : IRequestHandler<UpdatePosPrinterSelectionCommand, bool>
        {
            private readonly Services.PosPrinterSelectionService _service;

            public UpdatePosPrinterSelectionCommandHandler(Services.PosPrinterSelectionService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePosPrinterSelectionCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePosPrinterSelectionCommandValidator : AbstractValidator<UpdatePosPrinterSelectionCommand>
        {
            public UpdatePosPrinterSelectionCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Key).NotEmpty().MaximumLength(100);
                RuleFor(c => c.Request.PrinterName).MaximumLength(255).When(x => x.Request.PrinterName != null);
            }
        }
    }
}
