using Api.Helpers;
using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class BarcodeService
    {
        public BarcodeRepository _barcodeRepository;
        public ProductRepository _productRepository;
        public BarcodeService(BarcodeRepository barcodeRepository, ProductRepository productRepository)
        {
            _barcodeRepository = barcodeRepository;
            _productRepository = productRepository;
        }
        public async Task<BarcodeDto> Create(CreateBarcodeRequest req, int companyId)
        {
            var cexists = _barcodeRepository.Existsbyvalue(req.Value, companyId);
            if (cexists == true)
                throw new InvalidOperationException($"A Barcode with the Value '{req.Value}' already exists.");
            var product = await _productRepository.GetByIdAsync(req.ProductId, companyId);
            if (product == null)
                throw new InvalidOperationException($"Product with Id '{req.ProductId}' does not exist.");
            var newbarcode = Barcode.Create(
                value: req.Value,
                productid: req.ProductId,
                companyId: companyId
            );
            await _barcodeRepository.Add(newbarcode);
            return new BarcodeDto
            {
                Id = newbarcode.Id,
                Value = newbarcode.Value,
                ProductId = newbarcode.ProductId,
                ProductName = product.Name,
                CompanyId = companyId,
                CompanyName = newbarcode.Company?.Name

            };
        }
        public async Task<BarcodeDto> Update(UpdateBarcodeRequest req, int companyId)
        {
            var entityToUpdate = await _barcodeRepository.GetBarCodeByIdQuery(req.Id, companyId);

            if (entityToUpdate == null)
                throw new InvalidOperationException("Barcode not found.");

            var conflict = await _barcodeRepository.GetByValueAsync(req.NewBarcodeValue, companyId);

            if (conflict != null && conflict.Id != req.Id)
            {
                throw new InvalidOperationException($"The Barcode '{req.NewBarcodeValue}' is already assigned to another product.");
            }
            entityToUpdate.UpdateValue(req.NewBarcodeValue);

            await _barcodeRepository.UpdateAsync(entityToUpdate);

            return new BarcodeDto
            {
                Id = entityToUpdate.Id,
                Value = entityToUpdate.Value,
                ProductName = entityToUpdate.Product?.Name,
                CompanyName = entityToUpdate.Company?.Name
            };
        }
        public async Task<bool> Delete(DeleteBarcodeRequest req, int companyId)
        {
            var barcode = await _barcodeRepository.GetByValueAsync(req.Value, companyId);
            if (barcode == null)
                throw new InvalidOperationException($"Barcode with Value '{req.Value}' does not exist.");
            
            await _barcodeRepository.DeleteAsync(barcode);
            return true;
        }
    }
}
