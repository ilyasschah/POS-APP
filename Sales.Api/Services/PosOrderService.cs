using Sales.Api.Domain;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class PosOrderService
    {
        public readonly PosOrderRepository _repository;

        public PosOrderService(PosOrderRepository repository)
        {
            _repository = repository;
        }
        public async Task<PosOrder> Create(CreatePosOrderRequest req)
        {
            if (await _repository.ExistsAsync(req.Number))
                throw new InvalidOperationException($"An order with number '{req.Number}' already exists.");

            var newEntity = PosOrder.Create(req.UserId, req.Number, req.Discount, req.DiscountType, req.Total, req.CustomerId);

            await _repository.AddAsync(newEntity);
            return newEntity;
        }

        public async Task<bool> Update(int id, UpdatePosOrderRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null)
                throw new InvalidOperationException($"A PosOrder with the ID '{id}' does not exist.");

            entity.Update(req.UserId, req.Number, req.Discount, req.DiscountType, req.Total, req.CustomerId);

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null)
                return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}