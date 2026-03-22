using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.TaxesCommands.Delete
{
    public class DeleteTaxCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }

        public DeleteTaxCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteTaxCommandHandler : IRequestHandler<DeleteTaxCommand, bool>
        {
            private readonly TaxService _taxService;

            public DeleteTaxCommandHandler(TaxService taxService)
            {
                _taxService = taxService;
            }

            public async Task<bool> Handle(DeleteTaxCommand command, CancellationToken cancellationToken)
            {
                return await _taxService.DeleteAsync(command.Id, command.CompanyId);
            }
        }

        public class DeleteTaxCommandValidator : AbstractValidator<DeleteTaxCommand>
        {
            public DeleteTaxCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Tax ID must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
            }
        }
    }
}