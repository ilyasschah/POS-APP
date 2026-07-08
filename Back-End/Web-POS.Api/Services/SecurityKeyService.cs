using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Services
{
    public class SecurityKeyService
    {
        private readonly SecurityKeyRepository _repository;

        public SecurityKeyService(SecurityKeyRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<SecurityKeyDto>> GetAllAsync(int companyId)
        {
            var entities = await _repository.GetAllAsync(companyId);

            return entities.Select(MapperSecurityKey.MapToDto).ToList();
        }

        public async Task<SecurityKeyDto?> GetByNameAsync(string name, int companyId)
        {
            var entity = await _repository.GetByNameAsync(name, companyId);

            if (entity == null) return null;

            return MapperSecurityKey.MapToDto(entity);
        }

        public async Task<bool> UpdateAsync(UpdateSecurityKeyRequest req, int companyId)
        {
            var entity = await _repository.GetByNameAsync(req.Name, companyId);

            if (entity == null) return false; 

            entity.UpdateLevel(req.Level);

            return await _repository.UpdateAsync(entity);
        }
    }
}