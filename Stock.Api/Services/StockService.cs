using Stocks.Api.Domain;
using Stocks.Api.Repository;

namespace Stocks.Api.Services
{
    public class StockService
    {
        public StockRepository _stockRepository;
        public WarehouseRepository _warehouseRepository;
        public StockService(StockRepository stockRepository, WarehouseRepository warehouseRepository)
        {
            _stockRepository = stockRepository;
            _warehouseRepository = warehouseRepository;
        }
        public async Task<bool> Create(decimal quantity, int warehouseid, int productid)
        {
            var cexist = _stockRepository.Exist(productid);
            if (cexist == true)
                throw new InvalidOperationException($"A warehouse with the id '{warehouseid}' already exists.");
            var newstock = Stock.Create(quantity, warehouseid, productid);
            await _stockRepository.Add(newstock);
            return true;
        }
    }
}
