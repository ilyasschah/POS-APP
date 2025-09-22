using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PosPrinterSelectionSettingsCommands.Add
{
    public class AddPosPrinterSelectionSettingsCommand : IRequest<PosPrinterSelectionSettingsDto>
    {
        public CreatePosPrinterSelectionSettingsRequest Request { get; }

        public AddPosPrinterSelectionSettingsCommand(CreatePosPrinterSelectionSettingsRequest request)
        {
            Request = request;
        }

        public class AddPosPrinterSelectionSettingsCommandHandler
            : IRequestHandler<AddPosPrinterSelectionSettingsCommand, PosPrinterSelectionSettingsDto>
        {
            private readonly PosPrinterSelectionSettingsService _service;

            public AddPosPrinterSelectionSettingsCommandHandler(PosPrinterSelectionSettingsService service)
            {
                _service = service;
            }

            public async Task<PosPrinterSelectionSettingsDto> Handle(AddPosPrinterSelectionSettingsCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperPosPrinterSelectionSettings.MapToPosPrinterSelectionSettingsDto(entity);
            }
        }

        public class AddPosPrinterSelectionSettingsCommandValidator : AbstractValidator<AddPosPrinterSelectionSettingsCommand>
        {
            public AddPosPrinterSelectionSettingsCommandValidator()
            {
                RuleFor(c => c.Request.PosPrinterSelectionId).GreaterThan(0);
                RuleFor(c => c.Request.PaperWidth).GreaterThan(0).When(x => x.Request.PaperWidth.HasValue);
                RuleFor(c => c.Request.NumberOfCopies).GreaterThan(0).When(x => x.Request.NumberOfCopies.HasValue);
                RuleFor(c => c.Request.CashDrawerCommand).MaximumLength(100).When(x => x.Request.CashDrawerCommand != null);
                RuleFor(c => c.Request.FontName).MaximumLength(255).When(x => x.Request.FontName != null);
            }
        }
    }
}
