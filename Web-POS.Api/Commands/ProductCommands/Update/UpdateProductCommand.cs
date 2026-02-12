using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommands.Update
{
    public class UpdateProductCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateProductRequest Request { get; }
        public int CompanyId { get; }

        public UpdateProductCommand(int id, UpdateProductRequest request, int companyId)
        {
            Id = id;
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateProductCommandHandler : IRequestHandler<UpdateProductCommand, bool>
        {
            private readonly ProductService _service;

            public UpdateProductCommandHandler(ProductService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateProductCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request, command.CompanyId);
            }
        }

        public class UpdateProductCommandValidator : AbstractValidator<UpdateProductCommand>
        {
            public UpdateProductCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(c => c.Request.Price).GreaterThanOrEqualTo(0);
                RuleFor(c => c.Request.Code).MaximumLength(100).When(x => x.Request.Code != null);
                RuleFor(c => c.Request.MeasurementUnit).MaximumLength(50).When(x => x.Request.MeasurementUnit != null);
                RuleFor(c => c.Request.Color).NotEmpty().MaximumLength(50);
            }
        }
    }
}
