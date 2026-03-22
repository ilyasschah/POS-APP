using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class CurrencyService
    {
        private readonly CurrencyRepository _repository;

        public CurrencyService(CurrencyRepository repository)
        {
            _repository = repository;
        }

        public async Task<Currency> Create(CreateCurrencyRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
                throw new InvalidOperationException($"Currency with name '{req.Name}' already exists.");

            var entity = Currency.Create(req.Name, req.Code);
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateCurrencyRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                ?? throw new InvalidOperationException($"Currency with ID '{id}' not found.");

            var existingByName = await _repository.GetByNameAsync(req.Name);
            if (existingByName != null && existingByName.Id != id)
                throw new InvalidOperationException($"Another currency with name '{req.Name}' already exists.");

            entity.Update(req.Name, req.Code);
            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
