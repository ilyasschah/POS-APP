using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class MigrationService
    {
        private readonly MigrationRepository _repository;

        public MigrationService(MigrationRepository repository)
        {
            _repository = repository;
        }

        public async Task<Migration> Create(CreateMigrationRequest req)
        {
            if (await _repository.ExistsByVersionAsync(req.Version))
                throw new InvalidOperationException($"A migration with version '{req.Version}' already exists.");

            var entity = Migration.Create(
                version: req.Version,
                description: req.Description,
                fileName: req.FileName,
                module: req.Module,
                date: req.Date
            );

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateMigrationRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                ?? throw new InvalidOperationException($"Migration with ID '{id}' not found.");

            var sameVersion = await _repository.GetByVersionAsync(req.Version);
            if (sameVersion != null && sameVersion.Id != id)
                throw new InvalidOperationException($"Another migration with version '{req.Version}' already exists.");

            entity.Update(
                version: req.Version,
                description: req.Description,
                fileName: req.FileName,
                module: req.Module,
                date: req.Date
            );

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
