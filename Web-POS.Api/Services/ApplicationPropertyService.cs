using Products.Api.Models;
using Products.Api.Repository;
using Products.Api.Domain;

namespace Products.Api.Services
{
    public class ApplicationPropertyService
    {
        private readonly ApplicationPropertyRepository _repository;

        public ApplicationPropertyService(ApplicationPropertyRepository repository)
        {
            _repository = repository;
        }

        public async Task<ApplicationPropertyDto> Create(CreateApplicationPropertyRequest req, int companyId)
        {
            var exists = await _repository.ExistsAsync(req.Name, companyId);
            if (exists == true)
            {
                throw new InvalidOperationException($"Property with name '{req.Name}' already exists.");
            }
            var newapplicationProperty = ApplicationProperty.Create(
                name: req.Name,
                value: req.Value,
                companyId: companyId
            );
            await _repository.AddAsync(newapplicationProperty);
            return new ApplicationPropertyDto
            {
                Name = newapplicationProperty.Name,
                Value = newapplicationProperty.Value,
                CompanyId = newapplicationProperty.CompanyId
            };
        }
        public async Task<ApplicationPropertyDto> UpdateValue(UpdateApplicationPropertyRequest req,int companyId)
        {
            var entityToUpdate = await _repository.GetByNameAsync(req.Name, companyId);
            if (entityToUpdate == null)
                throw new InvalidOperationException("Application Property not found.");
            
            entityToUpdate.Update(req.NewValue);
            await _repository.UpdateAsync(entityToUpdate);
            return new ApplicationPropertyDto
            {
                Name = entityToUpdate.Name,
                Value = entityToUpdate.Value,
                CompanyId = entityToUpdate.CompanyId
            };
        }
    }
}
