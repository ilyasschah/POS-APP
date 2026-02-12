using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class WarehouseService
    {
        public WarehouseRepository _warehouseRepository;
        public WarehouseService (WarehouseRepository warehouseRepository)
        {
            _warehouseRepository = warehouseRepository;
        }
        public async Task<bool> Create(string name, int companyId)
        {
            if (_warehouseRepository.Exists(name, companyId))
                throw new InvalidOperationException($"A warehouse with the Name '{name}' already exists.");
            var newwarehouse = Warehouse.Create(name);
            await _warehouseRepository.Add(newwarehouse);
            return true;
        }
        public async Task<bool> Update(int id, string name, int companyId)
        {
            var entity = await _warehouseRepository.GetwarehouseByIdAsync(id, companyId);
            if (entity == null) return false;
            entity.UpdateName(name);
            await _warehouseRepository.UpdateAsync(entity);
            return true;
        }
        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _warehouseRepository.GetwarehouseByIdAsync(id, companyId);
            if (entity == null) return false;
            await _warehouseRepository.DeleteAsync(entity);
            return true;
        }
    }
}
