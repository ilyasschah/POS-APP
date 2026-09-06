using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ApplicationPropertyCommands.Add
{
    public class AddApplicationPropertyCommand : IRequest<ApplicationPropertyDto>
    {
        public CreateApplicationPropertyRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddApplicationPropertyCommand(CreateApplicationPropertyRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddApplicationPropertyCommandHandler : IRequestHandler<AddApplicationPropertyCommand, ApplicationPropertyDto>
        {
            private readonly ApplicationPropertyService _service;

            public AddApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public async Task<ApplicationPropertyDto> Handle(AddApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }

        public class AddApplicationPropertyCommandValidator : AbstractValidator<AddApplicationPropertyCommand>
        {
            public AddApplicationPropertyCommandValidator()
            {
                RuleFor(o => o.Request.Name).NotNull().NotEmpty().WithMessage("Property Name must not be empty.");
                // 🚨 NotNull only — an EMPTY value is legitimate and must stay so.
                //
                // CompanyDefaultsSeeder seeds four properties with "" on every new
                // company: PosSession.CashPaymentTypeIds, General.DefaultTaxRateIds,
                // Kitchen.DisplayIps and Database.BackupPath. For those, empty IS the
                // value — "nothing selected", "no backup path configured" — and the
                // Settings screen clearing one is a normal edit, not bad input.
                //
                // The old NotEmpty() fired on every one of those saves. In observe
                // mode that was only a warning per save; enforced, it would have
                // returned 400 and made those four settings impossible to clear.
                // (Receipt.Header and Receipt.Footer are seeded as " " — a single
                // space — which looks a lot like someone already working around
                // exactly this rule.)
                RuleFor(o => o.Request.Value).NotNull().WithMessage("Property Value must not be null.");
                RuleFor(o => o.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}