using Api.Domain;
using Api.Models;
using Api.Repository;
using System;
using System.Threading.Tasks;

namespace Api.Services
{
    public class VoidReasonService
    {
        public readonly VoidReasonRepository _repository;

        public VoidReasonService(VoidReasonRepository repository)
        {
            _repository = repository;
        }

        public async Task<VoidReason> Create(CreateVoidReasonRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
            {
                throw new InvalidOperationException($"A void reason with the name '{req.Name}' already exists.");
            }

            var newReason = VoidReason.Create(req.Name, req.Rank);
            await _repository.AddAsync(newReason);
            return newReason;
        }

        public async Task<bool> Update(int id, UpdateVoidReasonRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A void reason with the ID '{id}' was not found.");
            }

            var existingByName = await _repository.GetByNameAsync(req.Name);
            if (existingByName != null && existingByName.Id != id)
            {
                throw new InvalidOperationException($"Another void reason with the name '{req.Name}' already exists.");
            }

            entityToUpdate.Update(req.Name, req.Rank);
            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entityToDelete = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}