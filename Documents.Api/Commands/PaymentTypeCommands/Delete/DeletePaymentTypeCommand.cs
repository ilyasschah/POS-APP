using Documents.Api.Services;
using MediatR;

namespace Documents.Api.Commands.PaymentTypeCommands.Delete
{
    public class DeletePaymentTypeCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePaymentTypeCommand(int id)
        {
            Id = id;
        }

        public class DeletePaymentTypeCommandHandler : IRequestHandler<DeletePaymentTypeCommand, bool>
        {
            private readonly PaymentTypeService _service;

            public DeletePaymentTypeCommandHandler(PaymentTypeService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePaymentTypeCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}