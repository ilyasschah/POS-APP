using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Services;

namespace Api.Commands.StartingCashCommands.Delete
{
    public class DeleteStartingCashCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteStartingCashCommand(int id)
        {
            Id = id;
        }

        public class DeleteStartingCashCommandHandler : IRequestHandler<DeleteStartingCashCommand, bool>
        {
            private readonly StartingCashService _service;

            public DeleteStartingCashCommandHandler(StartingCashService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteStartingCashCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}