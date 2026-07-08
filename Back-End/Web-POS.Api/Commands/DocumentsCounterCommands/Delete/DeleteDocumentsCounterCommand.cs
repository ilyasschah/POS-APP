using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Services;

namespace Api.Commands.DocumentsCounterCommands.Delete
{
    public class DeleteDocumentsCounterCommand : IRequest<bool>
    {
        public string Name { get; }

        public DeleteDocumentsCounterCommand(string name)
        {
            Name = name;
        }

        public class DeleteDocumentsCounterCommandHandler : IRequestHandler<DeleteDocumentsCounterCommand, bool>
        {
            private readonly DocumentsCounterService _service;

            public DeleteDocumentsCounterCommandHandler(DocumentsCounterService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteDocumentsCounterCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Name);
            }
        }
    }
}