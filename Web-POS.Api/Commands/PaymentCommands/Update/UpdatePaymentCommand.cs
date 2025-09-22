using FluentValidation;
using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Products.Api.Services;
using Products.Api.Models;

namespace Products.Api.Commands.PaymentCommands.Update
{
    public class UpdatePaymentCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public UpdatePaymentRequest Request { get; }

        public UpdatePaymentCommand(int id, UpdatePaymentRequest request) // <-- Add this constructor
        {
            Id = id;
            Request = request;
        }

        public class UpdatePaymentCommandHandler : IRequestHandler<UpdatePaymentCommand, bool>
        {
            private readonly PaymentService _service;

            public UpdatePaymentCommandHandler(PaymentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePaymentCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePaymentCommandValidator : AbstractValidator<UpdatePaymentCommand>
        {
            public UpdatePaymentCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Amount).GreaterThanOrEqualTo(0);
            }
        }
    }
}