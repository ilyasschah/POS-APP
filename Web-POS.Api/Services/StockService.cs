using Azure.Core;
using Api.Repository;
using Api.Domain;
using Api.Models;

namespace Api.Services
{
    public class StockService
    {
        public readonly StockRepository _stockRepository;
        private readonly ProductRepository _productRepository;
        private readonly WarehouseRepository _warehouseRepository;
        public StockService(StockRepository stockRepository, ProductRepository productRepository, WarehouseRepository warehouseRepository)
        {
            _stockRepository = stockRepository;
            _productRepository = productRepository;
            _warehouseRepository = warehouseRepository;
        }
        public async Task<StockDto> CreateStockAsync(CreateStockRequest request, int companyId)
        {
            var product = await _productRepository.GetByIdAsync(request.ProductId, companyId);
            if (product == null)
                throw new UnauthorizedAccessException($"Product with ID {request.ProductId} does not exist or does not belong to your company.");

            var warehouse = await _warehouseRepository.GetByIdAsync(request.WarehouseId, companyId);
            if (warehouse == null)
                throw new UnauthorizedAccessException($"Warehouse with ID {request.WarehouseId} does not exist or does not belong to your company.");

            var cexist = await _stockRepository.Existby_P_id_W_id(request.ProductId, request.WarehouseId, companyId);
            if (cexist)
                throw new InvalidOperationException($"A stock for product '{request.ProductId}' in warehouse '{request.WarehouseId}' already exists.");

            var newstock = Stock.Create(request.Quantity, request.WarehouseId, request.ProductId, companyId);
            await _stockRepository.Add(newstock);

            return new StockDto
            {
                Id = newstock.Id,
                CompanyId = companyId,
                Quantity = newstock.Quantity,
                WarehouseId = newstock.WarehouseId,
                ProductId = newstock.ProductId
            };
        }
        public async Task<bool> UpdateAsync(UpdateStockRequest request, int companyId)
        {
            var stock = await _stockRepository.GetStockByIdAsync(request.Id, companyId);
            if (stock == null)
                throw new KeyNotFoundException($"Stock with ID {request.Id} not found.");

            int targetProductId = request.newProductId ?? stock.ProductId;
            int targetWarehouseId = request.newWarehouseId ?? stock.WarehouseId;

            if (request.newProductId.HasValue && request.newProductId.Value != stock.ProductId)
            {
                var product = await _productRepository.GetByIdAsync(targetProductId, companyId);
                if (product == null)
                    throw new UnauthorizedAccessException($"Product with ID {targetProductId} does not exist or does not belong to your company.");
            }
            
            if (request.newWarehouseId.HasValue && request.newWarehouseId.Value != stock.WarehouseId)
            {
                var warehouse = await _warehouseRepository.GetByIdAsync(targetWarehouseId, companyId);
                if (warehouse == null)
                    throw new UnauthorizedAccessException($"Warehouse with ID {targetWarehouseId} does not exist or does not belong to your company.");
            }

            if ((request.newProductId.HasValue && request.newProductId.Value != stock.ProductId) ||
                (request.newWarehouseId.HasValue && request.newWarehouseId.Value != stock.WarehouseId))
            {
                var exists = await _stockRepository.Existby_P_id_W_id(targetProductId, targetWarehouseId, companyId);
                if (exists)
                    throw new InvalidOperationException($"A stock for product '{targetProductId}' in warehouse '{targetWarehouseId}' already exists.");
            }

            stock.UpdateDetails(
                request.newQuantity ?? stock.Quantity,
                targetWarehouseId,
                targetProductId
            );

            await _stockRepository.UpdateQuantityAsync(stock);

            return true;
        }
        public async Task<bool> Delete(int id, int companyId)
        {
            var stock = await _stockRepository.GetStockByIdAsync(id, companyId);
            if (stock == null)
                return false;
            await _stockRepository.DeleteQuantityAsync(id, companyId);
            return true;
        }
    }
}
