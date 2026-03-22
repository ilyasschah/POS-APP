using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.ZReportCommands.Add
{
    public class AddZReportCommand(CreateZReportRequest createZReportRequest) : IRequest<bool>
    {
        public CreateZReportRequest Request { get; set; } = createZReportRequest;
        public class AddZReportcommandHandler(ZReportservice Documentservice) : IRequestHandler<AddZReportCommand, bool>
        {
            private readonly ZReportservice _Documentservice = Documentservice;
            public Task<bool> Handle(AddZReportCommand request, CancellationToken cancellationToken)
            {
                return _Documentservice.Create(
                    request.Request.Number,
                    request.Request.FromDocumentId,
                    request.Request.ToDocumentId
                    );
            }
        }
    }
}

