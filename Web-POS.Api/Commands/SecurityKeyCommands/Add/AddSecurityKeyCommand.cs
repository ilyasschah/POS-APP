using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.SecurityKeyCommands.Add
{
    public class AddSecurityKeyCommand(CreateSecurityKeyRequest createSecurityKeyRequest) : IRequest<bool>
    {
        public CreateSecurityKeyRequest Request { get; set; } = createSecurityKeyRequest;
        public class AddSecurityKeyCommandHandler(SecurityKeyService securityKeyService) : IRequestHandler<AddSecurityKeyCommand, bool>
        {
            private readonly SecurityKeyService _securityKeyService = securityKeyService;

            public async Task<bool> Handle(AddSecurityKeyCommand request, CancellationToken cancellationToken)
            {
                return await _securityKeyService.Create(request.Request.Name, request.Request.Level);
            }
        }
    }
}
