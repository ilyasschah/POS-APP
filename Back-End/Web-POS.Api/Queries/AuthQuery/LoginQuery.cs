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

            // Pillar 4: enforce the seat cap at master login. A brand-new device
            // that would exceed the tenant's paid allowance (or an admin-blocked
            // device) is REFUSED here, so an over-cap terminal can't link at all —
            // and a logged-in device counts immediately (not only after its first
            // sync). Known / within-allowance devices are registered and allowed.
            // Fail-OPEN only on a control-plane error (exception) so a Master-DB
            // hiccup never blocks a legitimate customer (the hard seat block also
            // stays at the BatchSync ingress).
            if (!string.IsNullOrWhiteSpace(request.Request.DeviceId))
            {
                try
                {
                    // The name is the terminal's own POS name ("POS1"), which is
                    // also its document-number prefix. It used to be the constant
                    // "POS terminal", so every row in DeviceRegistry carried the
                    // same useless label and the admin device list could only show
                    // the UUID. A client that sends none leaves the stored name
                    // untouched (see RegisterOrValidateDeviceAsync).
                    var seat = await _provisioning.RegisterOrValidateDeviceAsync(
                        user.CompanyId, request.Request.DeviceId!, request.Request.DeviceName, isInteractiveLogin: true);

                    if (!seat.Allowed &&
                        (seat.Reason == "seat_limit_exceeded" || seat.Reason == "device_blocked"))
                    {
                        return new LoginResponse
                        {
                            Success = false,
                            Message = seat.Reason == "seat_limit_exceeded"
                                ? $"This account is licensed for {seat.SeatAllowance} terminal(s) and that limit is reached. Sign out another device before linking this one."
                                : "This device has been blocked by the account administrator.",
                        };
                    }
                }
                catch { /* control plane unavailable — fail open */ }
            }

            var (token, expiresIn) = _tokenService.CreateJwt(user.Email!, user.Id, user.AccessLevel, user.CompanyId);

            // Pillar 2: issue the signed offline subscription lease for this
            // company so the terminal can enforce the subscription offline.
            var lease = await _leaseService.IssueLeaseAsync(user.CompanyId);

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
