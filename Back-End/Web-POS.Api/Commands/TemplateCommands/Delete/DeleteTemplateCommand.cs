using MediatR;
using Api.Services;

namespace Api.Commands.TemplateCommands.Delete
{
    public class DeleteTemplateCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteTemplateCommand(int id)
        {
            Id = id;
        }

        public class DeleteTemplateCommandHandler
            : IRequestHandler<DeleteTemplateCommand, bool>
        {
            private readonly TemplateService _service;

            public DeleteTemplateCommandHandler(TemplateService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteTemplateCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
