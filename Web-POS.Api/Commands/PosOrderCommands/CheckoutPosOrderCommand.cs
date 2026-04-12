using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderCommand
{
    public class CheckoutPosOrderCommand : IRequest<bool>
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

        public class CheckoutPosOrderCommandHandler : IRequestHandler<CheckoutPosOrderCommand, bool>
        {
            private readonly PosOrderCheckoutService _service;

            public CheckoutPosOrderCommandHandler(PosOrderCheckoutService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(CheckoutPosOrderCommand command, CancellationToken cancellationToken)
            {
                await _service.CheckoutAsync(command.CompanyId, command.UserId, command.Request);
                return true;
            }
        }
    }
}