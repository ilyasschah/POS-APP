using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderCommands
{
    public class CheckoutPosOrderCommand : IRequest<int>
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

        public class CheckoutPosOrderCommandHandler : IRequestHandler<CheckoutPosOrderCommand, int>
        {
            private readonly PosOrderCheckoutService _service;

            public CheckoutPosOrderCommandHandler(PosOrderCheckoutService service)
            {
                _service = service;
            }

            // Returns the server-assigned Document.Id so callers (BatchSync,
            // PosOrdersController) can echo it back to the client.  The client
            // uses it to stamp the local Document row's serverId after sync.
            public async Task<int> Handle(CheckoutPosOrderCommand command, CancellationToken cancellationToken)
            {
                var document = await _service.CheckoutAsync(
                    command.CompanyId, command.UserId, command.Request);
                return document.Id;
            }
        }
    }
}