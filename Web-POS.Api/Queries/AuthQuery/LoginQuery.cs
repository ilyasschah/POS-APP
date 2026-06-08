using MediatR;
using Api.Models;
using Api.Services;
using Api.Repository;

namespace Api.Queries.AuthQuery;

public class LoginQuery : IRequest<LoginResponse>
{
    public LoginRequest Request { get; set; }

    public LoginQuery(LoginRequest request)
    {
        Request = request;
    }

    public class LoginQueryHandler : IRequestHandler<LoginQuery, LoginResponse>
    {
        private readonly TokenService _tokenService;
        private readonly UserRepository _userRepository;

        public LoginQueryHandler(TokenService tokenService, UserRepository userRepository)
        {
            _tokenService = tokenService;
            _userRepository = userRepository;
        }

        public async Task<LoginResponse> Handle(LoginQuery request, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(request.Request.Email) || string.IsNullOrWhiteSpace(request.Request.Password))
                return new LoginResponse { Success = false, Message = "Email and password are required." };

            var user = await _userRepository.GetByEmailAnyCompanyAsync(request.Request.Email);

            if (user == null || !user.IsEnabled)
                return new LoginResponse { Success = false, Message = "Invalid credentials." };

            if (!BCrypt.Net.BCrypt.Verify(request.Request.Password, user.Password))
                return new LoginResponse { Success = false, Message = "Invalid credentials." };

            var (token, expiresIn) = _tokenService.CreateJwt(user.Email!);

            return new LoginResponse
            {
                Success = true,
                Token = token,
                ExpiresIn = expiresIn,
                User = new
                {
                    Id = user.Id,
                    Email = user.Email,
                    CompanyId = user.CompanyId,
                    AccessLevel = user.AccessLevel,
                },
            };
        }
    }
}
