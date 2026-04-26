using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderCommands
{
    public class UpdatePosOrderStatusCommand : IRequest<bool>
    {
        public int CompanyId { get; set; }
        public UpdatePosOrderStatusRequest Request { get; set; }

        public UpdatePosOrderStatusCommand(int companyId, UpdatePosOrderStatusRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class UpdatePosOrderStatusCommandHandler : IRequestHandler<UpdatePosOrderStatusCommand, bool>
        {
            private readonly PosOrderService _service;

            public UpdatePosOrderStatusCommandHandler(PosOrderService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdatePosOrderStatusCommand command, CancellationToken cancellationToken)
            {
                return await _service.UpdateStatus(command.CompanyId, command.Request);
            }
        }
    }
}