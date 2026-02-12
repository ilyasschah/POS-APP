using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.UserCommands.Delete;

public class DeleteUserCommand : IRequest<bool>
{
    public int Id { get; }
    public int CompanyId { get; }

    public DeleteUserCommand(int id, int companyId)
    {
        Id = id;
        CompanyId = companyId;
    }

    public class DeleteUserCommandHandler : IRequestHandler<DeleteUserCommand, bool>
    {
        private readonly UserService _service;

        public DeleteUserCommandHandler(UserService service)
        {
            _service = service;
        }

        public Task<bool> Handle(DeleteUserCommand request, CancellationToken cancellationToken)
        {
            return _service.Delete(request.Id, request.CompanyId);
        }
    }
}
