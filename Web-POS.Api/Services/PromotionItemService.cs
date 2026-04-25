using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PromotionItemService
    {
        private readonly PromotionItemRepository _repository;
        private readonly PromotionRepository _promotionRepository;

        public PromotionItemService(PromotionItemRepository repository , PromotionRepository promotionRepository)
        {
            _repository = repository;
            _promotionRepository = promotionRepository;
        }

        public async Task<PromotionItemDto> Create(int companyId, CreateSinglePromotionItemRequest req)
        {
            var promotion = await _promotionRepository.GetByIdAsync(req.PromotionId, companyId);
            if (promotion == null) throw new InvalidOperationException("Promotion not found.");

            var item = PromotionItem.Create(req.PromotionId, req.Uid, req.Value);
            item.CompanyId = companyId;
            item.DiscountType = req.DiscountType;
            item.PriceType = req.PriceType;
            item.IsConditional = req.IsConditional;
            item.Quantity = req.Quantity;
            item.ConditionType = req.ConditionType;
            item.QuantityLimit = req.QuantityLimit;

            await _repository.AddSingleItemAsync(item);
            return MapperPromotionItem.MapToDto(item);
        }

        public async Task<bool> Update(int companyId, UpdatePromotionItemRequest req)
        {
            var item = await _repository.GetItemByIdAsync(req.Id, companyId, trackEntity: true);
            if (item == null) throw new InvalidOperationException("Promotion Item not found.");

            item.Update(req.Uid, req.DiscountType, req.PriceType, req.Value, req.IsConditional, req.Quantity, req.ConditionType, req.QuantityLimit);

            await _repository.UpdateSingleItemAsync(item);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var item = await _repository.GetItemByIdAsync(id, companyId, trackEntity: true);
            if (item == null) return false;

            await _repository.DeleteSingleItemAsync(item);
            return true;
        }
    }
}