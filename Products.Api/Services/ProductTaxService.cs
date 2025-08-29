using Products.Api.Domain;
using Products.Api.Repository;
using System;
using System.Threading.Tasks;

namespace Products.Api.Services
{
    public class ProductTaxService
    {
        public readonly ProductTaxRepository _repository;

        public ProductTaxService(ProductTaxRepository repository)
        {
            _repository = repository;
        }

        public async Task<bool> Create(int productId, int taxId)
        {
            var exists = await _repository.ExistsAsync(productId, taxId);
            if (exists)
            {
                throw new InvalidOperationException($"The link between Product ID '{productId}' and Tax ID '{taxId}' already exists.");
            }

            var newProductTax = ProductTax.Create(productId, taxId);
            await _repository.AddAsync(newProductTax);
            return true;
        }

        public async Task<bool> Delete(int productId, int taxId)
        {
            var entityToDelete = await _repository.FindAsync(productId, taxId);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}