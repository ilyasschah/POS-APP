using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.UserCommands.Update;

public class UpdateUserCommand : IRequest<bool>
{
    public int Id { get; }
    public UpdateUserRequest Request { get; set; }
    public int CompanyId { get; }

    public UpdateUserCommand(int id, UpdateUserRequest request, int companyId)
    {
        Id = id;
        Request = request;
        CompanyId = companyId;
    }

    public class UpdateUserCommandHandler : IRequestHandler<UpdateUserCommand, bool>
    {
        private readonly UserService _service;

        public UpdateUserCommandHandler(UserService service)
        {
            _service = service;
        }

        public Task<bool> Handle(UpdateUserCommand request, CancellationToken cancellationToken)
        {
            return _service.Update(request.Id, request.Request, request.CompanyId);
        }
    }

    public class UpdateUserCommandValidator : AbstractValidator<UpdateUserCommand>
    {
        public UpdateUserCommandValidator()
        {
            RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
            RuleFor(c => c.Request.Username).NotNull().NotEmpty().WithMessage("Username is required.");
        }
    }
}
