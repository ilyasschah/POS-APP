using FluentValidation;
using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Products.Api.Services;
using Products.Api.Models;
using Products.Api.Helpers;

namespace Products.Api.Commands.PaymentTypeCommands.Add
{
    public class AddPaymentTypeCommand : IRequest<PaymentTypeDto>
    {
        public CreatePaymentTypeRequest Request { get; }

        public AddPaymentTypeCommand(CreatePaymentTypeRequest request)
        {
            Request = request;
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
                var newEntity = await _service.Create(command.Request);
                return MapperPaymentType.MapToPaymentTypeDto(newEntity);
            }
        }

        public class AddPaymentTypeCommandValidator : AbstractValidator<AddPaymentTypeCommand>
        {
            public AddPaymentTypeCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}