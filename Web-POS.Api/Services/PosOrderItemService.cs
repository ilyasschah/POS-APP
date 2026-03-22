using Api.Domain;
using Api.Models;
using Api.Repository;
using System.Reflection.Metadata;

namespace Api.Services
{
    public class PosOrderItemService 
    {
        private readonly PosOrderItemRepository _repository;

        public PosOrderItemService(PosOrderItemRepository repository)
        {
            _repository = repository;
        }

        public async Task<PosOrderItem> CreateAsync(CreatePosOrderItemRequest req)
        {
            if (await _repository.ExistsForOrderAsync(req.PosOrderId,req.ProductId))
            {
                throw new InvalidOperationException("This product already exists on the order.");
            }
            var newItem = PosOrderItem.Create(
                req.PosOrderId,
                req.ProductId,
                req.RoundNumber,
                req.Quantity,
                req.Price,
                req.Discount,
                req.DiscountType,
                req.Comment,
                req.Bundle
            );
            await _repository.AddAsync(newItem);
            return newItem;
        }

        public async Task<bool> UpdateAsync(UpdatePosOrderItemRequest request)
        {
            var existingItem = await _repository.GetByIdAsync(request.Id);
            if (existingItem == null)
            {
                throw new InvalidOperationException("Order item not found.");
            }

            existingItem.UpdateDetails(request.Quantity, request.Price, request.Discount, request.Comment);

            await _repository.UpdateAsync(existingItem);
            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var existingItem = await _repository.GetByIdAsync(id);
            if (existingItem == null)
            {
                throw new InvalidOperationException("Order item not found.");
            }

            await _repository.DeleteAsync(id);
            return true;
        }
    }
}
     
