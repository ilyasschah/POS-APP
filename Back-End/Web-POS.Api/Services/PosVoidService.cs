using Api.Models;
using Api.Domain;
using Api.Repository;

namespace Api.Services
{
    public class PosVoidService
    {
        public readonly PosVoidRepository _repository;

        public PosVoidService(PosVoidRepository repository)
        {
            _repository = repository;
        }
        public async Task<bool> Create(int companyId, string orderNumber, int? userId, string userName, int? productId, string productName, int roundNumber,
            decimal quantity, decimal price, decimal discount, int discountType, decimal total, string? bundle,
            string? reason = null, int? voidedById = null, string? voidedByName = null)
        {
            var newEntity = PosVoid.Create(
                companyId,
                orderNumber,
                userId,
                userName,
                productId,
                productName,
                roundNumber,
                quantity,
                price,
                discount,
                discountType,
                total,
                bundle,
                reason,
                voidedById,
                voidedByName
            );
            await _repository.AddAsync(newEntity);
            return true;
        }
        public async Task<bool> Update(int id, int voidedById, string? voidedByName, string? reason)
        {
            var entity = await _repository.GetByIdAsync(id);
            if (entity == null)
                throw new InvalidOperationException($"PosVoid with Id '{id}' does not exist.");
            entity.UpdateConfirmation(id, voidedById, voidedByName, reason);
            await _repository.UpdateAsync(entity);
            return true;
        }
        public async Task<bool> Delete(string? reason)
        {
            var entity = await _repository.GetByReasonAsync(reason);
            if (entity == null)
                return false;
            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}