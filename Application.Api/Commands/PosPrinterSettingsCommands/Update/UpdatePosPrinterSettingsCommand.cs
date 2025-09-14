using Products.Api.Models;
using Products.Api.Services;
using FluentValidation;
using MediatR;

namespace Products.Api.Commands.PosPrinterSettingsCommands.Update
{
    public class UpdatePosPrinterSettingsCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePosPrinterSettingsRequest Request { get; }

        public UpdatePosPrinterSettingsCommand(int id, UpdatePosPrinterSettingsRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdatePosPrinterSettingsCommandHandler
            : IRequestHandler<UpdatePosPrinterSettingsCommand, bool>
        {
            private readonly PosPrinterSettingsService _service;

            public UpdatePosPrinterSettingsCommandHandler(PosPrinterSettingsService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePosPrinterSettingsCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePosPrinterSettingsCommandValidator : AbstractValidator<UpdatePosPrinterSettingsCommand>
        {
            public UpdatePosPrinterSettingsCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.PrinterName).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.PaperWidth).GreaterThan(0);
                RuleFor(c => c.Request.NumberOfCopies).GreaterThan(0);
            }
        }
    }
}
