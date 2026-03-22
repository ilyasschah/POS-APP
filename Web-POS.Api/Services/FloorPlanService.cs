using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class FloorPlanService
    {
        public readonly FloorPlanRepository _repository;

        public FloorPlanService(FloorPlanRepository repository)
        {
            _repository = repository;
        }

        public async Task<FloorPlan> Create(CreateFloorPlanRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
            {
                throw new InvalidOperationException($"A floor plan with the name '{req.Name}' already exists.");
            }

            var newFloorPlan = FloorPlan.Create(req.Name, req.Color);
            await _repository.AddAsync(newFloorPlan);
            return newFloorPlan;
        }

        public async Task<bool> Update(int id, UpdateFloorPlanRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A floor plan with the ID '{id}' was not found.");
            }

            var existingByName = await _repository.GetByNameAsync(req.Name);
            if (existingByName != null && existingByName.Id != id)
            {
                throw new InvalidOperationException($"Another floor plan with the name '{req.Name}' already exists.");
            }

            entityToUpdate.Update(req.Name, req.Color ?? entityToUpdate.Color);
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