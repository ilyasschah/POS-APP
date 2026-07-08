using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class CustomerDiscountService
    {
        private readonly CustomerDiscountRepository _repository;

        public CustomerDiscountService(CustomerDiscountRepository repository)
        {
            _repository = repository;
        }

        public async Task<CustomerDiscount> Create(int companyId, CreateCustomerDiscountRequest req)
        {
            var existing = await _repository.GetByCustomerIdAsync(req.CustomerId, companyId);
            if (existing != null)
                throw new InvalidOperationException("This customer already has a discount applied. Update it instead.");

            var newEntity = CustomerDiscount.Create(req.CustomerId, req.Type, req.Uid, req.Value);
            newEntity.CompanyId = companyId; 

            await _repository.AddAsync(newEntity);
            return newEntity;
        }

        public async Task<bool> Update(int companyId, UpdateCustomerDiscountRequest req)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId, trackEntity: true);
            if (entity == null)
                throw new InvalidOperationException("Customer discount not found.");

            entity.Type = req.Type;
            entity.Value = req.Value;

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId, trackEntity: true);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}