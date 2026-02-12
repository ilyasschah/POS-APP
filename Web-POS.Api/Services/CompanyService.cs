using Products.Api.Domain;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using System.Net;

namespace Products.Api.Services;

public class CompanyService
{
    public readonly CompanyRepository _repository;
    public readonly CountryRepository _countryRepository;

    public CompanyService(CompanyRepository repository, CountryRepository countryRepository)
    {
        _repository = repository;
        _countryRepository = countryRepository;
    }

    public async Task<CompanyDto> Create(CreateCompanyRequest req)
    {
        if (await _repository.GetByNameAsync(req.Name) != null)
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");
        
        var newEntity = Company.Create(
            req.Name,
            req.CountryId
        );
        await _repository.AddAsync(newEntity);
        return new CompanyDto
        {
            Id = newEntity.Id,
            Name = newEntity.Name,
            CountryName = newEntity.Country.Name,
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
        var entityToUpdate = await _repository.GetByIdAsync(req.Id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");
        if (await _repository.GetByNameAsync(req.Name) != null)
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");
        entityToUpdate.UpdateDetails(
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
            req.CountrySubentity);

        await _repository.UpdateAsync(entityToUpdate);
        return new CompanyDto
        {
            Id = entityToUpdate.Id,
            Name = entityToUpdate.Name,
            CountryName = entityToUpdate.Country.Name,
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
        var entityToUpdate = await _repository.GetByIdAsync(req.Id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");
        entityToUpdate.UpdateLogo(req.Logo);
        await _repository.UpdateAsync(entityToUpdate);
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var entityToDelete = await _repository.GetByIdAsync(id);
        if (entityToDelete == null)
            throw new InvalidOperationException($"A Company with the ID '{id}' does not exist.");

        await _repository.DeleteAsync(entityToDelete);
        return true;
    }
}
