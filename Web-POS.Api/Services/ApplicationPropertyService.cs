using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class ApplicationPropertyService
    {
        private readonly ApplicationPropertyRepository _repository;
        private readonly CompanyRepository _companyRepository;

        public ApplicationPropertyService(ApplicationPropertyRepository repository, CompanyRepository companyRepository)
        {
            _repository = repository;
            _companyRepository = companyRepository;
        }

        public async Task<ApplicationPropertyDto> CreateAsync(CreateApplicationPropertyRequest req, int companyId)
        {
            var exists = await _repository.ExistsAsync(req.Name, companyId);
            if (exists)
            {
                throw new InvalidOperationException($"Property with name '{req.Name}' already exists.");
            }

            var newApplicationProperty = ApplicationProperty.Create(
                companyId,
                req.Name,
                req.Value
            );

            await _repository.AddAsync(newApplicationProperty);

            var company = await _companyRepository.GetByIdAsync(companyId);

            return new ApplicationPropertyDto
            {
                Id = newApplicationProperty.Id,
                Name = newApplicationProperty.Name,
                Value = newApplicationProperty.Value,
                CompanyName = company?.Name
            };
        }

        public async Task<bool> UpdateValueAsync(UpdateApplicationPropertyRequest req, int companyId)
        {
            var entityToUpdate = await _repository.GetByIdAsync(req.Id, companyId);
            if (entityToUpdate == null)
                throw new InvalidOperationException("Application Property not found.");

            entityToUpdate.UpdateValue(req.NewValue);
            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }
    }
}