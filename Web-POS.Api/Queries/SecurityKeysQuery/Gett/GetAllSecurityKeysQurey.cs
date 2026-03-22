using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.SecurityKeysQuery.Gett
{
    public class GetAllSecurityKeysQurey : IRequest<List<SecurityKeyDto>>
    {
        public class GetAllSecurityKeysQureyHandler : IRequestHandler<GetAllSecurityKeysQurey, List<SecurityKeyDto>>
        {
            private readonly SecurityKeyRepository _securityKeyRepository;
            public GetAllSecurityKeysQureyHandler(SecurityKeyRepository securityKeyRepository)
            {
                _securityKeyRepository = securityKeyRepository;
            }
            public async Task<List<SecurityKeyDto>> Handle(GetAllSecurityKeysQurey request, CancellationToken cancellationToken)
            {
                var securityKeys = await _securityKeyRepository.GetSecurityKeysAsync();
                return securityKeys.Select(MapperSecurityKey.MapToSecurityKey).ToList();
            }
        }
    }
}

