using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services;

public class CompanyService
{
    public readonly CompanyRepository _companyRepository;
    public readonly CountryRepository _countryRepository;

    public CompanyService(CompanyRepository companyRepository, CountryRepository countryRepository)
    {
        _companyRepository = companyRepository;
        _countryRepository = countryRepository;
    }

    public async Task<CompanyDto> Create(CreateCompanyRequest req)
    {
        if (await _companyRepository.GetByNameAsync(req.Name) != null)
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");

        var newEntity = Company.Create(
            req.Name,
            req.CountryId,
            req.Address,
            req.PostalCode,
            req.City,
            req.TaxNumber,
            req.Email,
            req.PhoneNumber,
            req.BankAccountNumber,
            req.BankDetails,
            req.StreetName,
            req.AdditionalStreetName,
            req.BuildingNumber,
            req.PlotIdentification,
            req.CitySubdivisionName,
            req.CountrySubentity
        );

        await _companyRepository.AddAsync(newEntity);
        return  new CompanyDto
        {
            Id = newEntity.Id,
            Name = newEntity.Name,
            CountryName = (await _countryRepository.GetCountryIdQuery(newEntity.CountryId))?.Name,
            Address = newEntity.Address,
            PostalCode = newEntity.PostalCode,
            City = newEntity.City,
            TaxNumber = newEntity.TaxNumber,
            Email = newEntity.Email,
            PhoneNumber = newEntity.PhoneNumber,
            BankAccountNumber = newEntity.BankAccountNumber,
            BankDetails = newEntity.BankDetails,
            StreetName = newEntity.StreetName,
            AdditionalStreetName = newEntity.AdditionalStreetName,
            BuildingNumber = newEntity.BuildingNumber,
            PlotIdentification = newEntity.PlotIdentification,
            CitySubdivisionName = newEntity.CitySubdivisionName,
            CountrySubentity = newEntity.CountrySubentity
        };
    }

    public async Task<CompanyDto> Update_DetailsAsync(UpdateCompanyRequest req)
    {
        var entityToUpdate = await _companyRepository.GetByIdAsync(req.Id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");
        var existingName = await _companyRepository.GetByNameAsync(req.Name);
        if (existingName != null && existingName.Id != req.Id)
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");
        entityToUpdate.UpdateDetails(
            req.Name, 
            req.CountryId,
            req.Address ?? entityToUpdate.Address,
            req.PostalCode ?? entityToUpdate.PostalCode,
            req.City ?? entityToUpdate.City,
            req.TaxNumber ?? entityToUpdate.TaxNumber,
            req.Email ?? entityToUpdate.Email,
            req.PhoneNumber ?? entityToUpdate.PhoneNumber,
            req.BankAccountNumber ?? entityToUpdate.BankAccountNumber,
            req.BankDetails ?? entityToUpdate.BankDetails,
            req.StreetName ?? entityToUpdate.StreetName,
            req.AdditionalStreetName ?? entityToUpdate.AdditionalStreetName,
            req.BuildingNumber ?? entityToUpdate.BuildingNumber,
            req.PlotIdentification ?? entityToUpdate.PlotIdentification,
            req.CitySubdivisionName ?? entityToUpdate.CitySubdivisionName,
            req.CountrySubentity ?? entityToUpdate.CountrySubentity
        );

        await _companyRepository.UpdateAsync(entityToUpdate);

        return new CompanyDto
        {
            Id = entityToUpdate.Id,
            Name = entityToUpdate.Name,
            CountryName = (await _countryRepository.GetCountryIdQuery(entityToUpdate.CountryId))?.Name,
            Address = entityToUpdate.Address,
            PostalCode = entityToUpdate.PostalCode,
            City = entityToUpdate.City,
            TaxNumber = entityToUpdate.TaxNumber,
            Email = entityToUpdate.Email,
            PhoneNumber = entityToUpdate.PhoneNumber,
            BankAccountNumber = entityToUpdate.BankAccountNumber,
            BankDetails = entityToUpdate.BankDetails,
            StreetName = entityToUpdate.StreetName,
            AdditionalStreetName = entityToUpdate.AdditionalStreetName,
            BuildingNumber = entityToUpdate.BuildingNumber,
            PlotIdentification = entityToUpdate.PlotIdentification,
            CitySubdivisionName = entityToUpdate.CitySubdivisionName,
            CountrySubentity = entityToUpdate.CountrySubentity
        };
    }
    public async Task<bool> Update_LogoAsync(UpdateCompanyLogoRequest req)
    {
        var entityToUpdate = await _companyRepository.GetByIdAsync(req.Id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");
        entityToUpdate.UpdateLogo(req.Logo);
        await _companyRepository.UpdateAsync(entityToUpdate);
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var entityToDelete = await _companyRepository.GetByIdAsync(id);
        if (entityToDelete == null)
            throw new InvalidOperationException($"A Company with the ID '{id}' does not exist.");

        await _companyRepository.DeleteAsync(entityToDelete);
        return true;
    }
}
