using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.UserCommands.Add;

public class AddUserCommand : IRequest<bool>
{
    public CreateUserRequest Request { get; set; }

    public AddUserCommand(CreateUserRequest request)
    {
        Request = request;
    }

    public class AddUserCommandHandler : IRequestHandler<AddUserCommand, bool>
    {
        private readonly UserService _service;

        public AddUserCommandHandler(UserService service)
        {
            _service = service;
        }

        public Task<bool> Handle(AddUserCommand request, CancellationToken cancellationToken)
        {
            return _service.Create(request.Request);
        }
    }

    public class AddUserCommandValidator : AbstractValidator<AddUserCommand>
    {
        public AddUserCommandValidator()
        {
            RuleFor(c => c.Request.Username).NotNull().NotEmpty().WithMessage("Username is required.");
            RuleFor(c => c.Request.Password).NotNull().NotEmpty().WithMessage("Password is required.");
        }
    }
}
