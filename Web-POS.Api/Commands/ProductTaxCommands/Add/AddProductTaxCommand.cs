using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductTaxCommands.Add
{
    public class AddProductTaxCommand : IRequest<bool>
    {
        public CreateProductTaxRequest Request { get; set; }

        public class AddProductTaxCommandHandler : IRequestHandler<AddProductTaxCommand, bool>
        {
            private readonly ProductTaxService _service;

            public AddProductTaxCommandHandler(ProductTaxService service)
            {
                _service = service;
            }

            public Task<bool> Handle(AddProductTaxCommand command, CancellationToken cancellationToken)
            {
                return _service.Create(command.Request.ProductId, command.Request.TaxId);
            }
        }

        public class AddProductTaxCommandValidator : AbstractValidator<AddProductTaxCommand>
        {
            public AddProductTaxCommandValidator()
            {
                RuleFor(c => c.Request.ProductId).GreaterThan(0);
                RuleFor(c => c.Request.TaxId).GreaterThan(0);
            }
        }
    }
}