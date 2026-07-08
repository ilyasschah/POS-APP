using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class TemplateService
    {
        private readonly TemplateRepository _repository;

        public TemplateService(TemplateRepository repository)
        {
            _repository = repository;
        }

        public async Task<Template> Create(CreateTemplateRequest req)
        {
            if (await _repository.ExistsByNameAsync(req.Name))
                throw new InvalidOperationException($"Template with name '{req.Name}' already exists.");

            var entity = Template.Create(req.Name, req.Value);
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateTemplateRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"Template with ID '{id}' not found.");

            var existingByName = await _repository.GetByNameAsync(req.Name);
            if (existingByName != null && existingByName.Id != id)
                throw new InvalidOperationException($"Another template with name '{req.Name}' already exists.");

            entity.Update(req.Name, req.Value);

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
