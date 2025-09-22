using FluentValidation;
using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.ProductTaxCommands.Delete
{
    public class DeleteProductTaxCommand : IRequest<bool>
    {
        public int ProductId { get; set; }
        public int TaxId { get; set; }

        public class DeleteProductTaxCommandHandler : IRequestHandler<DeleteProductTaxCommand, bool>
        {
            private readonly ProductTaxService _service;

            public DeleteProductTaxCommandHandler(ProductTaxService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteProductTaxCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.ProductId, command.TaxId);
            }
        }

        public class DeleteProductTaxCommandValidator : AbstractValidator<DeleteProductTaxCommand>
        {
            public DeleteProductTaxCommandValidator()
            {
                RuleFor(c => c.ProductId).GreaterThan(0);
                RuleFor(c => c.TaxId).GreaterThan(0);
            }
        }
    }
}