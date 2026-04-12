using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PosOrderItemService
    {
        public readonly PosOrderItemRepository _repository;

        public PosOrderItemService(PosOrderItemRepository repository)
        {
            _repository = repository;
        }

        public async Task<PosOrderItem> Create(int companyId, CreatePosOrderItemRequest req)
        {
            var newEntity = PosOrderItem.Create(
                companyId,
                req.PosOrderId,
                req.ProductId,
                req.RoundNumber,
                req.Quantity,
                req.Price,
                req.Discount,
                req.DiscountType,
                req.DiscountAppliedType,
                req.Comment,
                req.Bundle
            );

            await _repository.AddAsync(newEntity);
            return newEntity;
        }

        public async Task<bool> Update(int companyId, UpdatePosOrderItemRequest req)
        {
            // We pass companyId here to ensure one tenant can't update another tenant's order items!
            var entity = await _repository.GetByIdAsync(req.Id, companyId, trackEntity: true);

            if (entity == null)
                throw new InvalidOperationException($"A PosOrderItem with the ID '{req.Id}' does not exist.");

            // The Domain entity will automatically throw an error here if IsLocked is true
            entity.UpdateDetails(
                req.Quantity,
                req.Price,
                req.Discount,
                req.DiscountType,
                req.DiscountAppliedType,
                req.Comment
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId, trackEntity: true);

            if (entity == null)
                return false;

            if (entity.IsLocked)
                throw new InvalidOperationException("You cannot delete an item that has already been sent to the kitchen. Please use the Void function instead.");

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}