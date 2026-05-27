using Api.Models;
using Api.Repository;
using Api.Domain;
using Api.Helpers;

namespace Api.Services
{
    public class FloorPlanTableService
    {
        private readonly FloorPlanTableRepository _repository;

        public FloorPlanTableService(FloorPlanTableRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<FloorPlanTableDto>> GetAllAsync(int companyId, DateTime? modifiedAfter = null)
        {
            var entities = await _repository.GetAllAsync(companyId, modifiedAfter);
            return entities.Select(MapperFloorPlanTable.MapToDto).ToList();
        }

        public async Task<List<FloorPlanTableDto>> GetByFloorPlanIdAsync(int floorPlanId, int companyId)
        {
            return await _repository.GetByFloorPlanIdAsync(floorPlanId, companyId);
        }

        public async Task<FloorPlanTableDto?> GetByIdAsync(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId);
            return entity == null ? null : MapperFloorPlanTable.MapToDto(entity);
        }

        public async Task<FloorPlanTableDto?> GetByNameAsync(string name, int companyId)
        {
            var entity = await _repository.GetByNameAsync(name, companyId);
            return entity == null ? null : MapperFloorPlanTable.MapToDto(entity);
        }

        public async Task<FloorPlanTableDto> CreateAsync(CreateFloorPlanTableRequest req, int companyId)
        {
            var entity = FloorPlanTable.Create(
                companyId,
                req.FloorPlanId,
                req.Name,
                req.PositionX,
                req.PositionY,
                req.Width,
                req.Height,
                req.IsRound);

            var savedEntity = await _repository.AddAsync(entity);
            return MapperFloorPlanTable.MapToDto(savedEntity);
        }

        public async Task<bool> UpdateGeometryAsync(UpdateTableGeometryRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId);
            if (entity == null) return false;

            entity.UpdateGeometry(req.PositionX, req.PositionY, req.Width, req.Height);
            return await _repository.UpdateAsync(entity);
        }

        public async Task<bool> UpdatePropertiesAsync(UpdateTablePropertiesRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId);
            if (entity == null) return false;

            entity.UpdateProperties(req.Name, req.IsRound);
            return await _repository.UpdateAsync(entity);
        }

        public async Task<bool> OccupyTableAsync(int tableId, int companyId)
        {
            var entity = await _repository.GetByIdAsync(tableId, companyId);
            if (entity == null) return false;

            entity.UpdateStatus(1);
            return await _repository.UpdateAsync(entity);
        }

        public async Task<bool> FreeTableAsync(int tableId, int companyId)
        {
            var entity = await _repository.GetByIdAsync(tableId, companyId);
            if (entity == null) return false;

            entity.UpdateStatus(0);
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