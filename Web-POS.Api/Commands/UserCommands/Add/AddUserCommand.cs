using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.UserCommands.Add;

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
            RuleFor(c => c.Request.Username)
                .NotNull().NotEmpty().WithMessage("Username is required.")
                .MinimumLength(3).WithMessage("Username must be at least 3 characters.")
                .MaximumLength(50).WithMessage("Username must not exceed 50 characters.");

            RuleFor(c => c.Request.Password)
                .NotNull().NotEmpty().WithMessage("Password is required.")
                .MinimumLength(6).WithMessage("Password must be at least 6 characters.");

            RuleFor(c => c.Request.Email)
                .EmailAddress().WithMessage("Email must be a valid email address.")
                .When(c => !string.IsNullOrWhiteSpace(c.Request.Email));
        }
    }
}
