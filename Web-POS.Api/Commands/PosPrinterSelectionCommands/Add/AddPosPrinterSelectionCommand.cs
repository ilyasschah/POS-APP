using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;

namespace Products.Api.Commands.PosPrinterSelectionCommands.Add
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
            private readonly Products.Api.Services.PosPrinterSelectionService _service;

            public AddPosPrinterSelectionCommandHandler(Products.Api.Services.PosPrinterSelectionService service)
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
