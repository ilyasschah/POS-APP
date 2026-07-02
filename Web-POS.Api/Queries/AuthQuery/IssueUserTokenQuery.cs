using MediatR;
using Api.Models;
using Api.Services;
using Api.Repository;

namespace Api.Queries.AuthQuery;

/// <summary>
/// Issues a JWT that acts as a specific POS user within a company. Backs both:
///   - /Auth/Refresh   — <c>UserId</c> = the caller's own token claim (sliding renew).
///   - /Auth/UserToken — <c>UserId</c> = the cashier being switched to at PIN login.
/// <c>CompanyId</c> always comes from the (device) token's claim, and the lookup
/// is scoped by it, so a device can only mint tokens for users in its own tenant.
/// </summary>
public class IssueUserTokenQuery : IRequest<LoginResponse>
{
    public int UserId { get; set; }
    public int CompanyId { get; set; }

    public IssueUserTokenQuery(int userId, int companyId)
    {
        UserId = userId;
        CompanyId = companyId;
    }

    public class IssueUserTokenQueryHandler : IRequestHandler<IssueUserTokenQuery, LoginResponse>
    {
        private readonly TokenService _tokenService;
        private readonly UserRepository _userRepository;

        public IssueUserTokenQueryHandler(TokenService tokenService, UserRepository userRepository)
        {
            _tokenService = tokenService;
            _userRepository = userRepository;
        }

        public async Task<LoginResponse> Handle(IssueUserTokenQuery request, CancellationToken cancellationToken)
        {
            if (request.UserId <= 0 || request.CompanyId <= 0)
                return new LoginResponse { Success = false, Message = "Invalid user or company." };

            // GetByIdAsync is scoped by companyId → cross-tenant requests return null.
            var user = await _userRepository.GetByIdAsync(request.UserId, request.CompanyId);

            if (user == null || !user.IsEnabled)
                return new LoginResponse { Success = false, Message = "User no longer valid." };

            var subject = user.Email ?? user.Username;
            var (token, expiresIn) = _tokenService.CreateJwt(subject, user.Id, user.AccessLevel, user.CompanyId);

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
