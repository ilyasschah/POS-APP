using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.ProductTaxCommands.Delete
{
    public class DeleteProductTaxCommand : IRequest<bool>
    {
        public int ProductId { get; set; }
        public int TaxId { get; set; }
        public int CompanyId { get; set; }

        public class DeleteProductTaxCommandHandler : IRequestHandler<DeleteProductTaxCommand, bool>
        {
            private readonly ProductTaxService _service;

            public DeleteProductTaxCommandHandler(ProductTaxService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteProductTaxCommand command, CancellationToken cancellationToken)
            {
                return await _service.DeleteAsync(command.ProductId, command.TaxId, command.CompanyId);
            }
        }

        public class DeleteProductTaxCommandValidator : AbstractValidator<DeleteProductTaxCommand>
        {
            public DeleteProductTaxCommandValidator()
            {
                RuleFor(c => c.ProductId).GreaterThan(0);
                RuleFor(c => c.TaxId).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}