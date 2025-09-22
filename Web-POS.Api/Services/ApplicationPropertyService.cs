using Products.Api.Models;
using Products.Api.Repository;
using Products.Api.Domain;

namespace Products.Api.Services
{
    public class ApplicationPropertyService
    {
        private readonly ApplicationPropertyRepository _repository;

        public ApplicationPropertyService(ApplicationPropertyRepository repository)
        {
            _repository = repository;
        }

        public async Task<ApplicationProperty> Create(CreateApplicationPropertyRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
                throw new InvalidOperationException($"A property with name '{req.Name}' already exists.");

            var entity = ApplicationProperty.Create(req.Name, req.Value);
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(string originalName, UpdateApplicationPropertyRequest req)
        {
            var existing = await _repository.GetByNameAsync(originalName, trackEntity: true)
                           ?? throw new InvalidOperationException($"Property '{originalName}' not found.");

            if (!string.Equals(originalName, req.Name, StringComparison.OrdinalIgnoreCase)
                && await _repository.ExistsAsync(req.Name))
                throw new InvalidOperationException($"Another property with name '{req.Name}' already exists.");

            var updated = ApplicationProperty.Create(req.Name, req.Value);
            await _repository.UpdateAsync(updated, originalName);
            return true;
        }

        public async Task<bool> Delete(string name)
        {
            var existing = await _repository.GetByNameAsync(name, trackEntity: true);
            if (existing == null) return false;

            await _repository.DeleteAsync(existing);
            return true;
        }
    }
}
