using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductTaxCommands.Add
{
    public class AddProductTaxCommand : IRequest<bool>
    {
        public required CreateProductTaxRequest Request { get; set; }
        public required int CompanyId { get; set; }

        public class AddProductTaxCommandHandler : IRequestHandler<AddProductTaxCommand, bool>
        {
            private readonly ProductTaxService _service;
            public AddProductTaxCommandHandler(ProductTaxService service)
            {
                _service = service;
            }
            public async Task<bool> Handle(AddProductTaxCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }

        public class AddProductTaxCommandValidator : AbstractValidator<AddProductTaxCommand>
        {
            public AddProductTaxCommandValidator()
            {
                RuleFor(c => c.Request.ProductId).GreaterThan(0);
                RuleFor(c => c.Request.TaxId).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}