using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PromotionService
    {
        private readonly PromotionRepository _repository;

        public PromotionService(PromotionRepository repository)
        {
            _repository = repository;
        }

        public async Task<PromotionDto> Create(int companyId, CreatePromotionRequest req)
        {
            var promotion = Promotion.Create(req.Name, req.DaysOfWeek);
            promotion.CompanyId = companyId;
            promotion.StartDate = req.StartDate;
            promotion.StartTime = req.StartTime;
            promotion.EndDate = req.EndDate;
            promotion.EndTime = req.EndTime;

            var items = req.Items.Select(i =>
            {
                var item = PromotionItem.Create(0, i.Uid, i.Value);
                item.CompanyId = companyId;
                item.DiscountType = i.DiscountType;
                item.PriceType = i.PriceType;
                item.IsConditional = i.IsConditional;
                item.Quantity = i.Quantity;
                item.ConditionType = i.ConditionType;
                item.QuantityLimit = i.QuantityLimit;
                return item;
            }).ToList();

            await _repository.AddPromotionAsync(promotion, items);
            return MapperPromotion.MapToDto(promotion, items);
        }

        public async Task<bool> Update(int companyId, UpdatePromotionRequest req)
        {
            var promotion = await _repository.GetByIdAsync(req.Id, companyId, trackEntity: true);
            if (promotion == null) throw new InvalidOperationException("Promotion not found.");

            promotion.Update(req.Name, req.StartDate, req.StartTime, req.EndDate, req.EndTime, req.DaysOfWeek, req.IsEnabled);

            var items = req.Items.Select(i =>
            {
                var item = PromotionItem.Create(promotion.Id, i.Uid, i.Value);
                item.CompanyId = companyId;
                item.DiscountType = i.DiscountType;
                item.PriceType = i.PriceType;
                item.IsConditional = i.IsConditional;
                item.Quantity = i.Quantity;
                item.ConditionType = i.ConditionType;
                item.QuantityLimit = i.QuantityLimit;
                return item;
            }).ToList();

            await _repository.UpdatePromotionAsync(promotion, items);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var promotion = await _repository.GetByIdAsync(id, companyId, trackEntity: true);
            if (promotion == null) return false;

            await _repository.DeletePromotionAsync(promotion);
            return true;
        }
    }
}