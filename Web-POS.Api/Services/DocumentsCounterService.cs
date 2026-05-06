using Api.Domain;
using Api.Models;
using Api.Repository;
using System;
using System.Threading.Tasks;

namespace Api.Services
{
    public class DocumentsCounterService
    {
        public readonly DocumentsCounterRepository _repository;

        public DocumentsCounterService(DocumentsCounterRepository repository)
        {
            _repository = repository;
        }

        public async Task<DocumentsCounter> Create(CreateDocumentsCounterRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
            {
                throw new InvalidOperationException($"A counter with the name '{req.Name}' already exists.");
            }

            var newCounter = DocumentsCounter.Create(req.Name, req.Value, req.CompanyId);
            await _repository.AddAsync(newCounter);
            return newCounter;
        }

        public async Task<bool> Update(string name, UpdateDocumentsCounterRequest req)
        {
            var entityToUpdate = await _repository.GetByNameAsync(name, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A counter with the name '{name}' was not found.");
            }

            entityToUpdate.UpdateValue(req.Value);
            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }

        public async Task<bool> Delete(string name)
        {
            var entityToDelete = await _repository.GetByNameAsync(name, trackEntity: true);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}