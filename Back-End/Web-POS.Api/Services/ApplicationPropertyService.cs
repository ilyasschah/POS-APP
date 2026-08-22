using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
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
            var company = await _companyRepository.GetByIdAsync(companyId);

            var existing = await _repository.GetByNameAsync(req.Name, companyId);
            if (existing != null)
            {
                existing.UpdateValue(req.Value);
                await _repository.UpdateAsync(existing);

                return new ApplicationPropertyDto
                {
                    Id = existing.Id,
                    Name = existing.Name ?? string.Empty,
                    Value = existing.Value ?? string.Empty,
                    CompanyName = company?.Name
                };
            }

            var newApplicationProperty = ApplicationProperty.Create(
                companyId,
                req.Name,
                req.Value
            );

            await _repository.AddAsync(newApplicationProperty);

            return new ApplicationPropertyDto
            {
                Id = newApplicationProperty.Id,
                Name = newApplicationProperty.Name ?? string.Empty,
                Value = newApplicationProperty.Value ?? string.Empty,
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