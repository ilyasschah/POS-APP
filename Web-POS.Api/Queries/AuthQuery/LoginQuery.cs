using MediatR;
using Api.Models;
using Api.Services;
using Api.Repository;
using Api.Master.Services;

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
        private readonly LeaseService _leaseService;
        private readonly ITenantProvisioningService _provisioning;

        public LoginQueryHandler(TokenService tokenService, UserRepository userRepository, LeaseService leaseService, ITenantProvisioningService provisioning)
        {
            _tokenService = tokenService;
            _userRepository = userRepository;
            _leaseService = leaseService;
            _provisioning = provisioning;
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

            // Pillar 2: issue the signed offline subscription lease for this
            // company so the terminal can enforce the subscription offline.
            var lease = await _leaseService.IssueLeaseAsync(user.CompanyId);

            // Pillar 4: register this terminal against the seat cap at login, so a
            // logged-in device counts immediately (not only after its first sync).
            // Non-fatal — a Master-DB hiccup or an over-cap device must not break
            // login (the hard seat block stays at the BatchSync ingress).
            if (!string.IsNullOrWhiteSpace(request.Request.DeviceId))
            {
                try
                {
                    await _provisioning.RegisterOrValidateDeviceAsync(
                        user.CompanyId, request.Request.DeviceId!, "POS terminal");
                }
                catch { /* control plane unavailable — ignore */ }
            }

            return new LoginResponse
            {
                Success = true,
                Token = token,
                ExpiresIn = expiresIn,
                Lease = lease,
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
