using Api.Domain;
using Api.Models;
using Api.Repository;
using System;
using System.Threading.Tasks;

namespace Api.Services
{
    public class ProductTaxService
    {
        public readonly ProductTaxRepository _repository;

        public ProductTaxService(ProductTaxRepository repository)
        {
            _repository = repository;
        }

        public async Task<bool> CreateAsync(CreateProductTaxRequest request, int companyId)
        {
            var exists = await _repository.ExistsAsync(request.ProductId, request.TaxId, companyId);
            if (exists)
            {
                throw new InvalidOperationException($"The link between Product ID '{request.ProductId}' and Tax ID '{request.TaxId}' already exists.");
            }

            var newProductTax = ProductTax.Create(request.ProductId, request.TaxId, companyId);

            await _repository.AddAsync(newProductTax);
            return true;
        }

        public async Task<bool> DeleteAsync(int productId, int taxId, int companyId)
        {
            var entityToDelete = await _repository.FindAsync(productId, taxId, companyId);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}