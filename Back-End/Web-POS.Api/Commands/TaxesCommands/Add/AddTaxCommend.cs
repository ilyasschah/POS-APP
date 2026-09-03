using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.TaxesCommands.Add
{
    public class AddTaxCommand : IRequest<TaxDto>
    {
        public CreateTaxRequestDto Request { get; }
        public int CompanyId { get; } 

        public AddTaxCommand(CreateTaxRequestDto request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddTaxCommandHandler : IRequestHandler<AddTaxCommand, TaxDto>
        {
            private readonly TaxService _taxService;
            public AddTaxCommandHandler(TaxService taxService)
            {
                _taxService = taxService;
            }

            public async Task<TaxDto> Handle(AddTaxCommand command, CancellationToken cancellationToken)
            {
                return await _taxService.CreateAsync(command.Request, command.CompanyId);
            }
        }
    }
    public class AddTaxCommandValidator : AbstractValidator<AddTaxCommand>
    {
        public AddTaxCommandValidator()
        {
            RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Name must not be empty.");
            RuleFor(c => c.Request.Rate).GreaterThan(0).WithMessage("Tax rate must be greater than zero.");

            // Code is REQUIRED, and it is required HERE rather than only in the
            // tax form. UQ_Tax_Code_PerCompany is a unique index on
            // (CompanyId, Code) and SQL Server counts an EMPTY string as a
            // value, so a company can only ever hold ONE code-less tax — the
            // second one used to surface as a 500 out of a background sync.
            // Every tax carrying a code is what makes that limit unreachable,
            // so nothing but this validator may decide it: the API is shared by
            // the POS, the admin portal and the sync push.
            RuleFor(c => c.Request.Code)
                .NotNull().NotEmpty()
                .WithMessage("Tax code is required, and must be unique for your company.");

            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
        }
    }
}