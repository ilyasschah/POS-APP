using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.UserCommands.Add;

public class AddUserCommand : IRequest<UserDto>
{
    public CreateUserRequest Request { get; set; }
    public int CompanyId { get; }

    public AddUserCommand(CreateUserRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class AddUserCommandHandler : IRequestHandler<AddUserCommand, UserDto>
    {
        private readonly UserService _service;

        public AddUserCommandHandler(UserService service)
        {
            _service = service;
        }

        public async Task<UserDto> Handle(AddUserCommand request, CancellationToken cancellationToken)
        {
            return await _service.CreateAsync(request.Request, request.CompanyId);
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
