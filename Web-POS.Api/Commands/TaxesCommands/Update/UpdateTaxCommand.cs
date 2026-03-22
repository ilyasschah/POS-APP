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
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
            }
        }
    }
}