using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;
using FluentValidation;
using MediatR;

namespace Products.Api.Commands.PosPrinterSettingsCommands.Add
{
    public class AddPosPrinterSettingsCommand : IRequest<PosPrinterSettingsDto>
    {
        public CreatePosPrinterSettingsRequest Request { get; }

        public AddPosPrinterSettingsCommand(CreatePosPrinterSettingsRequest request)
        {
            Request = request;
        }

        public class AddPosPrinterSettingsCommandHandler
            : IRequestHandler<AddPosPrinterSettingsCommand, PosPrinterSettingsDto>
        {
            private readonly PosPrinterSettingsService _service;

            public AddPosPrinterSettingsCommandHandler(PosPrinterSettingsService service)
            {
                _service = service;
            }

            public async Task<PosPrinterSettingsDto> Handle(AddPosPrinterSettingsCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperPosPrinterSettings.MapToPosPrinterSettingsDto(entity);
            }
        }

        public class AddPosPrinterSettingsCommandValidator : AbstractValidator<AddPosPrinterSettingsCommand>
        {
            public AddPosPrinterSettingsCommandValidator()
            {
                RuleFor(c => c.Request.PrinterName).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.PaperWidth).GreaterThan(0).When(x => x.Request.PaperWidth.HasValue);
                RuleFor(c => c.Request.NumberOfCopies).GreaterThan(0).When(x => x.Request.NumberOfCopies.HasValue);
            }
        }
    }
}
