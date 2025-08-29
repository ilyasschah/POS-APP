using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Services;
using FluentValidation;
using MediatR;

namespace Documents.Api.Commands.PaymentCommands.Add
{
    public class AddPaymentCommand : IRequest<PaymentDto>
    {
        public CreatePaymentRequest Request { get; set; }
        public AddPaymentCommand(CreatePaymentRequest request) // <-- Add this constructor
        {
            Request = request;
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
                var newEntity = await _service.Create(command.Request);
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
            }
        }
    }
}