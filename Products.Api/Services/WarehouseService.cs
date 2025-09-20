using Products.Api.Domain;
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
        public async Task<bool> Create(string name)
        {
            var wexists = _warehouseRepository.Exists(name);
            if (wexists == true)
                throw new InvalidOperationException($"A warehouse with the Name '{name}' already exists.");
            var newwarehouse = Warehouse.Create(name);
            await _warehouseRepository.Add(newwarehouse);
            return true;
        }
    }
}
