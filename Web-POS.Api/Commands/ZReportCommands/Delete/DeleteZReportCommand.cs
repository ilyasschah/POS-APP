using MediatR;
using Api.Services;

namespace Api.Commands.ZReportCommands.Delete
{
    public class DeleteZReportCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteZReportCommand(int id)
        {
            Id = id;
        }
        public class DeleteZReportCommandHandler : IRequestHandler<DeleteZReportCommand, bool>
        {
            private readonly ZReportservice _service;

            public DeleteZReportCommandHandler(ZReportservice service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteZReportCommand request, CancellationToken cancellationToken)
            {
                return _service.Delete(request.Id );
            }
        }
    }
}
