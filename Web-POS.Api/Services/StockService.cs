using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class StockService
    {
        public readonly StockRepository _stockRepository;
        public readonly WarehouseRepository _warehouseRepository;
        public StockService(StockRepository stockRepository, WarehouseRepository warehouseRepository)
        {
            _stockRepository = stockRepository;
            _warehouseRepository = warehouseRepository;
        }
        public async Task<Stock> CreateStockAsync(CreateStockRequest request, int companyId)
        {
            var cexist = _stockRepository.Existby_P_id_W_id(request.ProductId, request.WarehouseId, companyId);
            if (cexist == true)
                throw new InvalidOperationException($"A stock for product with the id '{request.ProductId}' and warehouse with the id '{request.WarehouseId}' already exists.");
            var newstock = Stock.Create( 
                quantity: request.Quantity,
                warehouseid: request.WarehouseId,
                productid: request.ProductId
                );
            newstock.CompanyId = companyId;
            await _stockRepository.Add(newstock);
            return newstock;
        }
        public async Task<bool> Update(int id,UpdateStockRequest request, int companyId)
        {
            var stock = await _stockRepository.GetStockByIdQuery(id, companyId);
            if (stock == null)
                throw new InvalidOperationException($"Stock Cant be null");
            stock.Quantity = request.newQuantity;
            stock.WarehouseId = request.newWarehouseId;
            await _stockRepository.UpdateQuantityAsync(stock);
            return true;
        }
        public async Task<bool> Delete(int id, int companyId)
        {
            var stock = await _stockRepository.GetStockByIdQuery(id, companyId);
            if (stock == null)
                return false;
            await _stockRepository.DeleteQuantityAsync(stock);
            return true;
        }
    }
}
