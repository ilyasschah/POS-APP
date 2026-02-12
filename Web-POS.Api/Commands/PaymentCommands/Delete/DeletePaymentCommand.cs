using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.PaymentCommands.Delete
{
    public class DeletePaymentCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class DeletePaymentCommandHandler : IRequestHandler<DeletePaymentCommand, bool>
        {
            private readonly PaymentService _service;

            public DeletePaymentCommandHandler(PaymentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePaymentCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id, command.CompanyId);
            }
        }
    }
}