using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.UserCommands.Delete;

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

        public async Task<bool> Handle(DeleteUserCommand request, CancellationToken cancellationToken)
        {
            return await _service.Delete(request.Id, request.CompanyId);
        }
    }
    public class DeleteUserCommandValidator : AbstractValidator<DeleteUserCommand>
    {
        public DeleteUserCommandValidator()
        {
            RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
        }
    }
}
