using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;

namespace Api.Commands.PosPrinterSelectionCommands.Add
{
    public class AddPosPrinterSelectionCommand : IRequest<PosPrinterSelectionDto>
    {
        public CreatePosPrinterSelectionRequest Request { get; }

        public AddPosPrinterSelectionCommand(CreatePosPrinterSelectionRequest request)
        {
            Request = request;
        }

        public class AddPosPrinterSelectionCommandHandler
            : IRequestHandler<AddPosPrinterSelectionCommand, PosPrinterSelectionDto>
        {
            private readonly Services.PosPrinterSelectionService _service;

            public AddPosPrinterSelectionCommandHandler(Services.PosPrinterSelectionService service)
            {
                _service = service;
            }

            public async Task<PosPrinterSelectionDto> Handle(AddPosPrinterSelectionCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperPosPrinterSelection.MapToPosPrinterSelectionDto(entity);
            }
        }

        public class AddPosPrinterSelectionCommandValidator : AbstractValidator<AddPosPrinterSelectionCommand>
        {
            public AddPosPrinterSelectionCommandValidator()
            {
                RuleFor(c => c.Request.Key).NotEmpty().MaximumLength(100);
                RuleFor(c => c.Request.PrinterName).MaximumLength(255).When(x => x.Request.PrinterName != null);
            }
        }
    }
}
