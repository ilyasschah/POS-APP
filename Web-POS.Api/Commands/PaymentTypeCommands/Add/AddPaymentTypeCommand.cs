using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.PaymentTypeCommands.Add
{
    public class AddPaymentTypeCommand : IRequest<PaymentTypeDto>
    {
        public CreatePaymentTypeRequest Request { get; }
        public int CompanyId { get; }

        public AddPaymentTypeCommand(CreatePaymentTypeRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddPaymentTypeCommandHandler : IRequestHandler<AddPaymentTypeCommand, PaymentTypeDto>
        {
            private readonly PaymentTypeService _service;

            public AddPaymentTypeCommandHandler(PaymentTypeService service)
            {
                _service = service;
            }

            public async Task<PaymentTypeDto> Handle(AddPaymentTypeCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }
        public class AddPaymentTypeCommandValidator : AbstractValidator<AddPaymentTypeCommand>
        {
            public AddPaymentTypeCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Payment Type name is required.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
    
}