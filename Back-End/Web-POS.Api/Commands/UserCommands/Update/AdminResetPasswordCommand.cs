using MediatR;
using Api.Repository;
using Api.Models;

namespace Api.Commands.UserCommands.Update;

public class AdminResetPasswordCommand : IRequest<bool>
{
    public AdminResetPasswordRequest Request { get; set; }
    public int CompanyId { get; set; }

    public AdminResetPasswordCommand(AdminResetPasswordRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class AdminResetPasswordCommandHandler : IRequestHandler<AdminResetPasswordCommand, bool>
    {
        private readonly UserRepository _userRepository;

        public AdminResetPasswordCommandHandler(UserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        public async Task<bool> Handle(AdminResetPasswordCommand request, CancellationToken cancellationToken)
        {
            var user = await _userRepository.GetByIdAsync(request.Request.UserId, request.CompanyId);

            if (user == null)
                throw new InvalidOperationException("User not found.");

            // ✨ Hash the NEW password immediately. No need to check the old one!
            string hashedNewPassword = BCrypt.Net.BCrypt.HashPassword(request.Request.NewPassword);

            user.ChangePassword(hashedNewPassword);
            return await _userRepository.UpdateAsync(user);
        }
    }
}