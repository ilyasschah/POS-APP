using MediatR;
using Api.Repository;
using Api.Models;
using Api.Domain;

namespace Api.Commands.UserCommands.Update;

public class ChangePasswordCommand : IRequest<bool>
{
    public ChangePasswordRequest Request { get; set; }
    public int CompanyId { get; set; }

    public ChangePasswordCommand(ChangePasswordRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class ChangePasswordCommandHandler : IRequestHandler<ChangePasswordCommand, bool>
    {
        private readonly UserRepository _userRepository;

        public ChangePasswordCommandHandler(UserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        public async Task<bool> Handle(ChangePasswordCommand request, CancellationToken cancellationToken)
        {
            var user = await _userRepository.GetByIdAsync(request.Request.UserId, request.CompanyId);

            if (user == null)
                throw new InvalidOperationException("User not found.");

            if (!BCrypt.Net.BCrypt.Verify(request.Request.OldPassword, user.Password))
                throw new InvalidOperationException("Incorrect old password.");

            string hashedNewPassword = BCrypt.Net.BCrypt.HashPassword(request.Request.NewPassword);

            user.ChangePassword(hashedNewPassword);
            return await _userRepository.UpdateAsync(user);
        }
    }
}