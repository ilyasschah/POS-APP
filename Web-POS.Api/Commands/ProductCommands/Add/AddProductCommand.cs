using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommands.Add
{
    public class AddProductCommand : IRequest<ProductDto>
    {
        public CreateProductRequest Request { get; }
        public int CompanyId { get; }

        public AddProductCommand(CreateProductRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddProductCommandHandler : IRequestHandler<AddProductCommand, ProductDto>
        {
            private readonly ProductService _service;

            public AddProductCommandHandler(ProductService service)
            {
                _service = service;
            }

            public async Task<ProductDto> Handle(AddProductCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request, command.CompanyId);
                return MapperProduct.MapToProductDto(entity);
            }
        }

        public class AddProductCommandValidator : AbstractValidator<AddProductCommand>
        {
            public AddProductCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Price).GreaterThanOrEqualTo(0);
                RuleFor(c => c.Request.Code).MaximumLength(100).When(x => x.Request.Code != null);
                RuleFor(c => c.Request.MeasurementUnit).MaximumLength(50).When(x => x.Request.MeasurementUnit != null);
                RuleFor(c => c.Request.Color).MaximumLength(50).When(x => x.Request.Color != null);
            }
        }
    }
}
