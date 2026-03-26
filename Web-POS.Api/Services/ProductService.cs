using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class ProductService
    {
        private readonly ProductRepository _repository;

        public ProductService(ProductRepository repository)
        {
            _repository = repository;
        }

        private static byte[]? DecodeBase64(string? b64)
        {
            if (string.IsNullOrWhiteSpace(b64)) return null;
            try { return Convert.FromBase64String(b64); }
            catch { return null; }
        }


        public async Task<Product> Create(CreateProductRequest req, int companyId)
        {
            if (await _repository.ExistsByNameAsync(req.Name, companyId))
                throw new InvalidOperationException($"A product with the name '{req.Name}' already exists.");

            if (!string.IsNullOrWhiteSpace(req.Code) && await _repository.ExistsByCodeAsync(req.Code, companyId))
                throw new InvalidOperationException($"A product with the code '{req.Code}' already exists.");

            var entity = Product.Create(
                productGroupId: req.ProductGroupId,
                name: req.Name,
                code: req.Code,
                plu: req.PLU,
                measurementUnit: req.MeasurementUnit,
                price: req.Price,
                isTaxInclusivePrice: req.IsTaxInclusivePrice ?? true,
                currencyId: req.CurrencyId,
                isPriceChangeAllowed: req.IsPriceChangeAllowed ?? false,
                isService: req.IsService ?? false,
                isUsingDefaultQuantity: req.IsUsingDefaultQuantity ?? true,
                isEnabled: req.IsEnabled ?? true,
                description: req.Description,
                dateCreated: req.DateCreated ?? DateTime.UtcNow,
                dateUpdated: req.DateUpdated ?? DateTime.UtcNow,
                cost: req.Cost ?? 0m,
                markup: req.Markup ?? 0m,
                image: DecodeBase64(req.ImageBase64),
                color: string.IsNullOrWhiteSpace(req.Color) ? "Transparent" : req.Color!,
                ageRestriction: req.AgeRestriction,
                lastPurchasePrice: req.LastPurchasePrice ?? 0m,
                rank: req.Rank ?? 0
            );
            entity.CompanyId = companyId;

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateProductRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId, trackEntity: true);

            if (entity == null) return false;

            if (!string.IsNullOrWhiteSpace(req.Code))
            {
                var existsCode = await _repository.GetByCodeAsync(req.Code, companyId);
                if (existsCode != null && existsCode.Id != id)
                    throw new InvalidOperationException($"Another product with the code '{req.Code}' already exists.");
            }

            var imageBytes = DecodeBase64(req.ImageBase64) ?? entity.Image;

            entity.Update(
                productGroupId: req.ProductGroupId,
                name: req.Name,
                code: req.Code,
                plu: req.PLU,
                measurementUnit: req.MeasurementUnit,
                price: req.Price,
                isTaxInclusivePrice: req.IsTaxInclusivePrice,
                currencyId: req.CurrencyId,
                isPriceChangeAllowed: req.IsPriceChangeAllowed,
                isService: req.IsService,
                isUsingDefaultQuantity: req.IsUsingDefaultQuantity,
                isEnabled: req.IsEnabled,
                description: req.Description,
                dateUpdated: req.DateUpdated ?? DateTime.UtcNow,
                cost: req.Cost,
                markup: req.Markup,
                image: imageBytes,
                color: req.Color,
                ageRestriction: req.AgeRestriction,
                lastPurchasePrice: req.LastPurchasePrice,
                rank: req.Rank
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId, trackEntity: true);

            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}