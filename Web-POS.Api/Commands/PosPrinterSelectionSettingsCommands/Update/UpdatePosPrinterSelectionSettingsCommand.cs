using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosPrinterSelectionSettingsCommands.Update
{
    public class UpdatePosPrinterSelectionSettingsCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePosPrinterSelectionSettingsRequest Request { get; }

        public UpdatePosPrinterSelectionSettingsCommand(int id, UpdatePosPrinterSelectionSettingsRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdatePosPrinterSelectionSettingsCommandHandler
            : IRequestHandler<UpdatePosPrinterSelectionSettingsCommand, bool>
        {
            private readonly PosPrinterSelectionSettingsService _service;

            public UpdatePosPrinterSelectionSettingsCommandHandler(PosPrinterSelectionSettingsService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePosPrinterSelectionSettingsCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePosPrinterSelectionSettingsCommandValidator : AbstractValidator<UpdatePosPrinterSelectionSettingsCommand>
        {
            public UpdatePosPrinterSelectionSettingsCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.PosPrinterSelectionId).GreaterThan(0);
                RuleFor(c => c.Request.PaperWidth).GreaterThan(0);
                RuleFor(c => c.Request.NumberOfCopies).GreaterThan(0);
                RuleFor(c => c.Request.CashDrawerCommand).MaximumLength(100).When(x => x.Request.CashDrawerCommand != null);
                RuleFor(c => c.Request.FontName).MaximumLength(255).When(x => x.Request.FontName != null);
            }
        }
    }
}
