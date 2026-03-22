using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
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
                CompanyId = companyId

            };
        }

        public async Task<bool> UpdateAsync(UpdateTaxRequestDto req, int companyId)
        {
            var entity = await _repository.GetTaxByIdAsync(req.Id, companyId);
            if (entity == null)
                throw new InvalidOperationException($"Tax with ID '{req.Id}' not found.");
            var conflict = await _repository.GetByNameAsync(req.Name, companyId);
            if (conflict != null && conflict.Id != req.Id)
                throw new InvalidOperationException($"Another Tax with the name '{req.Name}' already exists.");
            entity.Name = req.Name ?? entity.Name;
            entity.Rate = req.Rate ?? entity.Rate;
            entity.Code = req.Code ?? entity.Code;
            entity.IsFixed = req.IsFixed ?? entity.IsFixed;
            entity.IsTaxOnTotal = req.IsTaxOnTotal ?? entity.IsTaxOnTotal;
            entity.IsEnabled = req.IsEnabled ?? entity.IsEnabled;

            await _repository.UpdateTaxAsync(entity);
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