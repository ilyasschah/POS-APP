using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Services;
using Api.Models;

namespace Api.Commands.PaymentCommands.Add
{
    public class AddPaymentCommand : IRequest<PaymentDto>
    {
        public CreatePaymentRequest Request { get; set; }
        public int CompanyId { get; set; }
        public AddPaymentCommand(CreatePaymentRequest request, int companyId) // <-- Add this constructor
        {
            Request = request;
            CompanyId = companyId;
        }
        public class AddPaymentCommandHandler : IRequestHandler<AddPaymentCommand, PaymentDto>
        {
            private readonly PaymentService _service;

            public AddPaymentCommandHandler(PaymentService service)
            {
                _service = service;
            }

            public async Task<PaymentDto> Handle(AddPaymentCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request, command.CompanyId);
                return MapperPayment.MapToPaymentDto(newEntity);
            }
        }

        public class AddPaymentCommandValidator : AbstractValidator<AddPaymentCommand>
        {
            public AddPaymentCommandValidator()
            {
                RuleFor(c => c.Request.DocumentId).GreaterThan(0);
                RuleFor(c => c.Request.PaymentTypeId).GreaterThan(0);
                RuleFor(c => c.Request.UserId).GreaterThan(0);
                RuleFor(c => c.Request.Amount).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}