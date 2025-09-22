using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.SecurityKeysQuery.Gett
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

