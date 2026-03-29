using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class BarcodeService
    {
        private readonly BarcodeRepository _barcodeRepository;
        private readonly ProductRepository _productRepository;

        public BarcodeService(BarcodeRepository barcodeRepository, ProductRepository productRepository)
        {
            _barcodeRepository = barcodeRepository;
            _productRepository = productRepository;
        }

        public async Task<BarcodeDto> Create(CreateBarcodeRequest req, int companyId)
        {
            var exists = await _barcodeRepository.ExistsByValueAsync(req.Value, companyId);
            if (exists)
                throw new InvalidOperationException($"A Barcode with the Value '{req.Value}' already exists.");

            var product = await _productRepository.GetByIdAsync(req.ProductId, companyId);
            if (product == null)
                throw new InvalidOperationException($"Product with Id '{req.ProductId}' does not exist.");

            var newBarcode = Barcode.Create(req.Value, req.ProductId, companyId);

            await _barcodeRepository.AddAsync(newBarcode);

            return new BarcodeDto
            {
                Id = newBarcode.Id,
                Value = newBarcode.Value,
                ProductId = newBarcode.ProductId,
                ProductName = product.Name
            };
        }

        public async Task<BarcodeDto> Update(UpdateBarcodeRequest req, int companyId)
        {
            var entityToUpdate = await _barcodeRepository.GetBarCodeByIdQuery(req.Id, companyId);

            if (entityToUpdate == null)
                throw new InvalidOperationException("Barcode not found.");

            var conflict = await _barcodeRepository.GetByValueAsync(req.Value, companyId);

            if (conflict != null && conflict.Id != req.Id)
            {
                throw new InvalidOperationException($"The Barcode '{req.Value}' is already assigned to another product.");
            }

            entityToUpdate.UpdateValue(req.Value);

            await _barcodeRepository.UpdateAsync(entityToUpdate);

            return new BarcodeDto
            {
                Id = entityToUpdate.Id,
                Value = entityToUpdate.Value,
                ProductId = entityToUpdate.ProductId,
                ProductName = entityToUpdate.Product?.Name ?? string.Empty
            };
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var barcode = await _barcodeRepository.GetBarCodeByIdQuery(id, companyId);
            if (barcode == null)
                throw new InvalidOperationException($"Barcode with Id '{id}' not found.");

            await _barcodeRepository.DeleteAsync(barcode);
            return true;
        }
    }
}