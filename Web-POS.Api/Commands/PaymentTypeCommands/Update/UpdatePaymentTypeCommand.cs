using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PaymentTypeCommands.Update
{
    public class UpdatePaymentTypeCommand : IRequest<bool>
    {
        public UpdatePaymentTypeRequest Request { get; }
        public int CompanyId { get; }

        public UpdatePaymentTypeCommand(UpdatePaymentTypeRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdatePaymentTypeCommandHandler : IRequestHandler<UpdatePaymentTypeCommand, bool>
        {
            private readonly PaymentTypeService _service;

            public UpdatePaymentTypeCommandHandler(PaymentTypeService service)
            {
                _service = service;
            }
            public Task<bool> Handle(UpdatePaymentTypeCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Request, command.CompanyId);

            }
        }
        public class UpdatePaymentTypeCommandValidator : AbstractValidator<UpdatePaymentTypeCommand>
        {
            public UpdatePaymentTypeCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Payment Type name is required.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}