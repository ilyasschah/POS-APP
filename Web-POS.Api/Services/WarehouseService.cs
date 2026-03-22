using Microsoft.AspNetCore.Mvc.Routing;
using Api.Domain;
using Api.Repository;
using Api.Models;

namespace Api.Services
{
    public class WarehouseService
    {
        private readonly WarehouseRepository _warehouseRepository;

        public WarehouseService(WarehouseRepository warehouseRepository)
        {
            _warehouseRepository = warehouseRepository;
        }

        public async Task<WarehouseDto> CreateAsync(CreateWarehouseRequest request, int companyId)
        {
            var exists = await _warehouseRepository.ExistsAsync(request.Name, companyId);
            if (exists)
                throw new InvalidOperationException($"A warehouse with the name '{request.Name}' already exists.");

            var newWarehouse = Warehouse.Create(
                companyId, 
                request.Name
            );

            await _warehouseRepository.AddAsync(newWarehouse);

            return new WarehouseDto
            {
                Id = newWarehouse.Id,
                Name = newWarehouse.Name,
                CompanyId = companyId
            };
        }

        public async Task<bool> UpdateAsync(UpdateWarehouseRequest request, int companyId)
        {
            var entity = await _warehouseRepository.GetByIdAsync(request.Id, companyId);
            if (entity == null) return false;

            var exists = await _warehouseRepository.ExistsAsync(request.Name, companyId);
            if (exists)
                throw new InvalidOperationException($"Another warehouse with the name '{request.Name}' already exists.");

            entity.Name = request.Name ?? entity.Name;
            await _warehouseRepository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await _warehouseRepository.GetByIdAsync(id, companyId);
            if (entity == null) return false;
            await _warehouseRepository.DeleteAsync(id, companyId);
            return true;
        }
    }
}