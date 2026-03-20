using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class WarehouseService
    {
        private readonly WarehouseRepository _warehouseRepository;
        private readonly CompanyRepository _companyRepository;

        public WarehouseService(WarehouseRepository warehouseRepository, CompanyRepository companyRepository)
        {
            _warehouseRepository = warehouseRepository;
            _companyRepository = companyRepository;
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

            var company = await _companyRepository.GetByIdAsync(companyId);

            return new WarehouseDto
            {
                Id = newWarehouse.Id,
                Name = newWarehouse.Name,
                CompanyName = company?.Name
            };
        }

        public async Task<bool> UpdateAsync(UpdateWarehouseRequest request, int companyId)
        {
            var entity = await _warehouseRepository.GetByIdAsync(request.Id, companyId);
            if (entity == null) return false;

            if (!string.IsNullOrWhiteSpace(request.Name) && request.Name != entity.Name)
            {
                var exists = await _warehouseRepository.ExistsAsync(request.Name, companyId);
                if (exists)
                    throw new InvalidOperationException($"Another warehouse with the name '{request.Name}' already exists.");

                entity.UpdateName(request.Name);
            }

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