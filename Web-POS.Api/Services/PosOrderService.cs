using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PosOrderService
    {
        public readonly PosOrderRepository _repository;

        public PosOrderService(PosOrderRepository repository)
        {
            _repository = repository;
        }

        // Added companyId here to pass to the Domain!
        public async Task<PosOrder> Create(int companyId, CreatePosOrderRequest req)
        {
            if (await _repository.ExistsAsync(req.Number))
                throw new InvalidOperationException($"An order with number '{req.Number}' already exists.");

            var newEntity = PosOrder.Create(
                companyId,
                req.UserId,
                req.Number,
                req.Discount,
                req.DiscountType,
                req.Total,
                req.CustomerId,
                req.ServiceType,
                // --- NEW FIELDS ---
                req.ServiceStatus,
                req.FloorPlanTableId
                //req.BookingId
            );

            await _repository.AddAsync(newEntity);
            return newEntity;
        }

        public async Task<bool> Update(UpdatePosOrderRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, trackEntity: true);
            if (entity == null)
                throw new InvalidOperationException($"A PosOrder with the ID '{req.Id}' does not exist.");
            entity.Update(
                req.UserId,
                req.Number,
                req.Discount,
                req.DiscountType,
                req.Total,
                req.CustomerId,
                req.ServiceType,
                // --- NEW FIELDS ---
                req.ServiceStatus,
                req.FloorPlanTableId
                //req.BookingId
            );

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