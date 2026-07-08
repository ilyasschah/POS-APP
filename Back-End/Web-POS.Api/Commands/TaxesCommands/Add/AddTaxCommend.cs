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
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
        }
    }
}