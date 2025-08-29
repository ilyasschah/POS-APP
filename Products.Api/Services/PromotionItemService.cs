using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class PromotionItemService
    {
        public readonly PromotionItemRepository _repository;

        public PromotionItemService(PromotionItemRepository repository)
        {
            _repository = repository;
        }

        public async Task<PromotionItem> Create(CreatePromotionItemRequest req)
        {
            var existingItems = await _repository.GetByPromotionIdAsync(req.PromotionId);
            if (existingItems.Any(i => i.Uid == req.Uid))
            {
                throw new InvalidOperationException($"This item (UID: {req.Uid}) already exists in this promotion.");
            }

            var newItem = PromotionItem.Create(
                req.PromotionId,
                req.Uid,
                req.Value ?? 0
            );

            newItem.DiscountType = req.DiscountType ?? 0;
            newItem.PriceType = req.PriceType ?? 0;
            newItem.IsConditional = req.IsConditional ?? true;
            newItem.Quantity = req.Quantity ?? 0;
            newItem.ConditionType = req.ConditionType ?? 0;
            newItem.QuantityLimit = req.QuantityLimit ?? 0;

            await _repository.AddAsync(newItem);
            return newItem;
        }

        public async Task<bool> Update(int id, UpdatePromotionItemRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A promotion item with the ID '{id}' was not found.");
            }

            var existingItems = await _repository.GetByPromotionIdAsync(entityToUpdate.PromotionId);
            if (existingItems.Any(i => i.Uid == req.Uid && i.Id != id))
            {
                throw new InvalidOperationException($"Another item (UID: {req.Uid}) already exists in this promotion.");
            }

            entityToUpdate.Update(
                req.Uid,
                req.DiscountType,
                req.PriceType,
                req.Value,
                req.IsConditional,
                req.Quantity,
                req.ConditionType,
                req.QuantityLimit
            );

            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entityToDelete = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}