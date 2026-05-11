using MediatR;
using Api.Models;
using Api.Services;

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

        // ---- TEMP credentials 
        private const string DemoUsername = "admin";
        private const string DemoPassword = "Admin@123";

        public LoginQueryHandler(TokenService tokenService)
        {
            _tokenService = tokenService;
        }

        public async Task<LoginResponse> Handle(LoginQuery request, CancellationToken cancellationToken)
        {

            if (string.IsNullOrWhiteSpace(request.Request.Username) || string.IsNullOrWhiteSpace(request.Request.Password))
            {
                return new LoginResponse { Success = false, Message = "Username and password are required." };
            }

            if (!string.Equals(request.Request.Username, DemoUsername, StringComparison.OrdinalIgnoreCase) ||
                request.Request.Password != DemoPassword)
            {
                return new LoginResponse { Success = false, Message = "Invalid credentials." };
            }

            var (token, expiresIn) = _tokenService.CreateJwt(request.Request.Username);

            return new LoginResponse
            {
                Success = true,
                Token = token,
                ExpiresIn = expiresIn,
                User = new { Id = 1, Username = DemoUsername, Roles = new[] { "Admin" } }
            };
        }
    }
}