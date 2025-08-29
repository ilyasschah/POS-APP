using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;
using System;
using System.Threading.Tasks;

namespace Products.Api.Services
{
    public class PromotionService
    {
        public readonly PromotionRepository _repository;

        public PromotionService(PromotionRepository repository)
        {
            _repository = repository;
        }

        public async Task<Promotion> Create(CreatePromotionRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
            {
                throw new InvalidOperationException($"A promotion with the name '{req.Name}' already exists.");
            }

            var newPromotion = Promotion.Create(req.Name, req.DaysOfWeek);

            newPromotion.StartDate = req.StartDate;
            newPromotion.StartTime = req.StartTime;
            newPromotion.EndDate = req.EndDate;
            newPromotion.EndTime = req.EndTime;
            newPromotion.IsEnabled = req.IsEnabled ?? true;

            await _repository.AddAsync(newPromotion);
            return newPromotion;
        }

        public async Task<bool> Update(int id, UpdatePromotionRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A promotion with the ID '{id}' was not found.");
            }

            var existingByName = await _repository.GetByNameAsync(req.Name);
            if (existingByName != null && existingByName.Id != id)
            {
                throw new InvalidOperationException($"Another promotion with the name '{req.Name}' already exists.");
            }

            entityToUpdate.Update(
                req.Name,
                req.StartDate,
                req.StartTime,
                req.EndDate,
                req.EndTime,
                req.DaysOfWeek,
                req.IsEnabled
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