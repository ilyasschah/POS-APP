using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderCommands
{
    public class CheckoutPosOrderCommand : IRequest<CheckoutResult>
    {
        public int CompanyId { get; set; }
        public int UserId { get; set; }
        public CheckoutPosOrderRequest Request { get; set; }

        public CheckoutPosOrderCommand(int companyId, int userId, CheckoutPosOrderRequest request)
        {
            CompanyId = companyId;
            UserId = userId;
            Request = request;
        }

        public class CheckoutPosOrderCommandHandler : IRequestHandler<CheckoutPosOrderCommand, CheckoutResult>
        {
            private readonly PosOrderCheckoutService _service;

            public CheckoutPosOrderCommandHandler(PosOrderCheckoutService service)
            {
                _service = service;
            }

            // Returns the server-assigned Document.Id plus the per-line
            // DocumentItem ids (keyed by client LineLocalId) so callers (BatchSync,
            // PosOrdersController) can echo them back. The client uses them to stamp
            // the local Document + document_items serverIds after sync.
            public async Task<CheckoutResult> Handle(CheckoutPosOrderCommand command, CancellationToken cancellationToken)
            {
                return await _service.CheckoutAsync(
                    command.CompanyId, command.UserId, command.Request);
            }
        }
    }
}