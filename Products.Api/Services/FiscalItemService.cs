using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;
using System;
using System.Threading.Tasks;

namespace Products.Api.Services
{
    public class FiscalItemService
    {
        public readonly FiscalItemRepository _repository;

        public FiscalItemService(FiscalItemRepository repository)
        {
            _repository = repository;
        }

        public async Task<FiscalItem> Create(CreateFiscalItemRequest req)
        {
            if (await _repository.ExistsAsync(req.PLU))
            {
                throw new InvalidOperationException($"A fiscal item with the PLU '{req.PLU}' already exists.");
            }

            var newFiscalItem = FiscalItem.Create(req.PLU, req.Name, req.VAT);
            await _repository.AddAsync(newFiscalItem);
            return newFiscalItem;
        }

        public async Task<bool> Update(int plu, UpdateFiscalItemRequest req)
        {
            var entityToUpdate = await _repository.GetByPluAsync(plu, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A fiscal item with the PLU '{plu}' was not found.");
            }

            entityToUpdate.Update(req.Name, req.VAT);
            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }

        public async Task<bool> Delete(int plu)
        {
            var entityToDelete = await _repository.GetByPluAsync(plu, trackEntity: true);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}