using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PaymentTypeCommands.Update
{
    public class UpdatePaymentTypeCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePaymentTypeRequest Request { get; }
        public int CompanyId { get; }

        public UpdatePaymentTypeCommand(int id, UpdatePaymentTypeRequest request, int companyId)
        {
            Id = id;
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
                try
                {
                    return _service.Update(command.Id, command.Request, command.CompanyId);
                }
                catch (Exception)
                {
                    throw;
                }
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