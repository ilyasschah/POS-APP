using Products.Api.Services;
using MediatR;

namespace Products.Api.Commands.ApplicationPropertyCommands.Delete
{
    public class DeleteApplicationPropertyCommand : IRequest<bool>
    {
        public string Name { get; }

        public DeleteApplicationPropertyCommand(string name)
        {
            Name = name;
        }

        public class DeleteApplicationPropertyCommandHandler
            : IRequestHandler<DeleteApplicationPropertyCommand, bool>
        {
            private readonly ApplicationPropertyService _service;

            public DeleteApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Name);
            }
        }
    }
}
