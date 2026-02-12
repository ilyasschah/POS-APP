using FluentValidation;
using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Products.Api.Services;
using Products.Api.Models;

namespace Products.Api.Commands.PaymentTypeCommands.Update
{
    public class UpdatePaymentTypeCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePaymentTypeRequest Request { get; }

        public UpdatePaymentTypeCommand(int id, UpdatePaymentTypeRequest request)
        {
            Id = id;
            Request = request;
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
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePaymentTypeCommandValidator : AbstractValidator<UpdatePaymentTypeCommand>
        {
            public UpdatePaymentTypeCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}