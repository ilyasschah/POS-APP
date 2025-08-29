using Sales.Api.Domain;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class FloorPlanTableService
    {
        public readonly FloorPlanTableRepository _repository;

        public FloorPlanTableService(FloorPlanTableRepository repository)
        {
            _repository = repository;
        }

        public async Task<FloorPlanTable> Create(CreateFloorPlanTableRequest req)
        {
            if (await _repository.ExistsAsync(req.Name, req.FloorPlanId))
            {
                throw new InvalidOperationException($"A table with the name '{req.Name}' already exists on this floor plan.");
            }

            var newTable = FloorPlanTable.Create(req.Name, req.FloorPlanId, req.Width, req.Height);

            newTable.PositionX = req.PositionX ?? 0;
            newTable.PositionY = req.PositionY ?? 0;
            newTable.IsRound = req.IsRound ?? false;

            await _repository.AddAsync(newTable);
            return newTable;
        }

        public async Task<bool> Update(int id, UpdateFloorPlanTableRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A table with the ID '{id}' was not found.");
            }

            if (entityToUpdate.Name.ToLower() != req.Name.ToLower())
            {
                if (await _repository.ExistsAsync(req.Name, entityToUpdate.FloorPlanId))
                {
                    throw new InvalidOperationException($"Another table with the name '{req.Name}' already exists on this floor plan.");
                }
            }

            entityToUpdate.Update(req.Name, req.PositionX, req.PositionY, req.Width, req.Height, req.IsRound);
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