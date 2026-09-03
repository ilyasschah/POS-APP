using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.TaxesCommands.Update
{
    public class UpdateTaxCommand : IRequest<bool>
    {
        public UpdateTaxRequestDto Request { get; }
        public int CompanyId { get; }

        public UpdateTaxCommand(UpdateTaxRequestDto request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateTaxCommandHandler : IRequestHandler<UpdateTaxCommand, bool>
        {
            private readonly TaxService _taxService;

            public UpdateTaxCommandHandler(TaxService taxService)
            {
                _taxService = taxService;
            }

            public async Task<bool> Handle(UpdateTaxCommand command, CancellationToken cancellationToken)
            {
                return await _taxService.UpdateAsync(command.Request, command.CompanyId);
            }
        }

        public class UpdateTaxCommandValidator : AbstractValidator<UpdateTaxCommand>
        {
            public UpdateTaxCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Tax ID must be valid.");
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Tax Name must not be empty.");
                RuleFor(c => c.Request.Rate).GreaterThan(0).WithMessage("Tax rate must be greater than zero.");

                // Code is required (see AddTaxCommandValidator), but on an
                // UPDATE a null Code means "leave it alone" — TaxService reads
                // it that way, and the sync push sends the row's stored value
                // verbatim. So only a code that is PRESENT and blank is
                // rejected: a legacy tax that predates the rule keeps syncing
                // untouched, and stops being code-less the first time someone
                // edits it.
                RuleFor(c => c.Request.Code)
                    .NotEmpty()
                    .When(c => c.Request.Code != null)
                    .WithMessage("Tax code cannot be blank, and must be unique for your company.");

                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
            }
        }
    }
}