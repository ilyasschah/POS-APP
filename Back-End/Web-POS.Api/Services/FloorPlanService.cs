using Api.Models;
using Api.Repository;
using Api.Domain;
using Api.Helpers;

namespace Api.Services
{
    public class FloorPlanService
    {
        private readonly FloorPlanRepository _repository;

        public FloorPlanService(FloorPlanRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<FloorPlanDto>> GetAllAsync(int companyId, DateTime? modifiedAfter = null)
        {
            var entities = await _repository.GetAllAsync(companyId, modifiedAfter);
            return entities.Select(MapperFloorPlan.MapToDto).ToList();
        }

        public async Task<FloorPlanDto?> GetByIdAsync(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId);
            return entity == null ? null : MapperFloorPlan.MapToDto(entity);
        }

        public async Task<FloorPlanDto> CreateAsync(CreateFloorPlanRequest req, int companyId)
        {
            var entity = FloorPlan.Create(companyId, req.Name, req.Color);
            var savedEntity = await _repository.AddAsync(entity);
            return MapperFloorPlan.MapToDto(savedEntity);
        }

        public async Task<bool> UpdateAsync(UpdateFloorPlanRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId);
            if (entity == null) return false;

            entity.Update(req.Name, req.Color);
            return await _repository.UpdateAsync(entity);
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId);
            if (entity == null) return false;

            return await _repository.DeleteAsync(entity);
        }
    }
}