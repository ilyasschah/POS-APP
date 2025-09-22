using Products.Api.Domain;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class SecurityKeyService
    {
        public SecurityKeyRepository _securityKeyRepository;
        public SecurityKeyService (SecurityKeyRepository securityKeyRepository)
        { _securityKeyRepository = securityKeyRepository; }
        public async Task<bool> Create(string name , int level)
        {
            var skexists = _securityKeyRepository.Exist(name);
            if (skexists == true)
                throw new InvalidOperationException($"A security key with the name '{name}' already exists.");
            var newsecuritykey = SecurityKey.Create(name, level);
            await _securityKeyRepository.Add(newsecuritykey);
            return true;
        }
    }
}
