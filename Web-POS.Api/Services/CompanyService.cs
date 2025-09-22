// FILE: Products.Api.Services\CompanyService.cs

using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services;

public class CompanyService
{
    public readonly CompanyRepository _repository;

    public CompanyService(CompanyRepository repository)
    {
        _repository = repository;
    }

    public async Task<bool> Create(CreateCompanyRequest req)
    {
        if (_repository.Exists(req.Name))
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");

        var newEntity = Company.Create(req.Name, req.CountryId);

        // Set optional properties
        newEntity.UpdateDetails(req.Name, req.CountryId, req.Address, req.PostalCode, req.City, req.TaxNumber, req.Email, req.PhoneNumber, req.BankAccountNumber, req.BankDetails, req.StreetName, req.AdditionalStreetName, req.BuildingNumber, req.PlotIdentification, req.CitySubdivisionName, req.CountrySubentity);

        await _repository.AddAsync(newEntity);
        return true;
    }

    public async Task<bool> Update(UpdateCompanyRequest req)
    {
        var entity = await _repository.GetByIdAsync(req.Id);
        if (entity == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");

        entity.UpdateDetails(req.Name, req.CountryId, req.Address, req.PostalCode, req.City, req.TaxNumber, req.Email, req.PhoneNumber, req.BankAccountNumber, req.BankDetails, req.StreetName, req.AdditionalStreetName, req.BuildingNumber, req.PlotIdentification, req.CitySubdivisionName, req.CountrySubentity);

        await _repository.UpdateAsync(entity);
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var entity = await _repository.GetByIdAsync(id);
        if (entity == null)
            return false; // Or throw

        await _repository.DeleteAsync(entity);
        return true;
    }
}
