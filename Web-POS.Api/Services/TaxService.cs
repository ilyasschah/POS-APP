using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository; 

namespace Products.Api.Services
{
    public class TaxService
    {
        private readonly TaxRepository _repository;
        public readonly CompanyRepository _companyRepository;

        public TaxService(TaxRepository repository, CompanyRepository companyRepository)
        {
            _repository = repository;
            _companyRepository = companyRepository;
        }

        public async Task<TaxDto> CreateAsync(CreateTaxRequestDto req, int companyId)
        {
            var existingTax = await _repository.GetByNameAsync(req.Name, companyId);
            if (existingTax != null)
                throw new InvalidOperationException($"A Tax with the name '{req.Name}' already exists for your company.");

           var newTax = Tax.Create(
                companyId, 
                req.Name,
                req.Rate,
                req.Code,
                req.IsFixed,
                req.IsTaxOnTotal,
                req.IsEnabled
            );

            await _repository.AddTaxAsync(newTax);
            return new TaxDto
            {
                Id = newTax.Id,
                Name = newTax.Name,
                Rate = newTax.Rate,
                Code = newTax.Code,
                IsFixed = newTax.IsFixed,
                IsTaxOnTotal = newTax.IsTaxOnTotal,
                IsEnabled = newTax.IsEnabled,
                CompanyName = (await _companyRepository.GetByIdAsync(companyId))?.Name

            };
        }

        public async Task<bool> UpdateAsync(UpdateTaxRequestDto req, int companyId)
        {
            var taxToUpdate = await _repository.GetTaxByIdAsync(req.Id, companyId);
            if (taxToUpdate == null)
                throw new InvalidOperationException($"Tax with ID '{req.Id}' not found.");
            var conflict = await _repository.GetByNameAsync(req.Name, companyId);
            if (conflict != null && conflict.Id != req.Id)
                throw new InvalidOperationException($"Another Tax with the name '{req.Name}' already exists.");
            taxToUpdate.UpdateDetails(
                req.Name,
                req.Rate,
                req.Code,
                req.IsFixed,
                req.IsTaxOnTotal,
                req.IsEnabled
            );

            await _repository.UpdateTaxAsync(taxToUpdate);

            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var taxToDelete = await _repository.GetTaxByIdAsync(id, companyId);
            if (taxToDelete == null) return false;

            await _repository.DeleteTaxAsync(taxToDelete.Id, companyId);
            return true;
        }
    }
}