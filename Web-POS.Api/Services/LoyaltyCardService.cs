// FILE: Products.Api.Services\LoyaltyCardService.cs

using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services;

public class LoyaltyCardService
{
    public readonly LoyaltyCardRepository _repository;

    public LoyaltyCardService(LoyaltyCardRepository repository)
    {
        _repository = repository;
    }

    public async Task<bool> Create(CreateLoyaltyCardRequest req)
    {
        if (_repository.ExistsForCustomer(req.CustomerId))
            throw new InvalidOperationException($"A LoyaltyCard for CustomerId '{req.CustomerId}' already exists.");

        var newEntity = LoyaltyCard.Create(req.CustomerId, req.CardNumber);

        await _repository.AddAsync(newEntity);
        return true;
    }

    public async Task<bool> Update(UpdateLoyaltyCardRequest req)
    {
        var entity = await _repository.GetByIdAsync(req.Id);
        if (entity == null)
            throw new InvalidOperationException($"A LoyaltyCard with the ID '{req.Id}' does not exist.");

        entity.Update(req.CardNumber);

        await _repository.UpdateAsync(entity);
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var entity = await _repository.GetByIdAsync(id);
        if (entity == null)
            return false;

        await _repository.DeleteAsync(entity);
        return true;
    }
}
