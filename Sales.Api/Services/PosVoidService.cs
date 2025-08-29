using Sales.Api.Domain;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class PosVoidService
    {
        public readonly PosVoidRepository _repository;

        public PosVoidService(PosVoidRepository repository)
        {
            _repository = repository;
        }
        public async Task<bool> Create(string orderNumber, int? userId, string userName, int? productId, string productName, int roundNumber,
            decimal quantity, decimal price, decimal discount, int discountType, decimal total, string? bundle)
        {
            if (_repository.Exists(orderNumber,roundNumber,productId ?? 0))
                throw new InvalidOperationException($"This item has already been voided in order '{orderNumber}'.");

            var newEntity = PosVoid.Create(
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
                bundle
            );
            await _repository.AddAsync(newEntity);
            return true;
        }
        public async Task<bool> Update(int id,int voidedById, string? voidedByName, string reason)
        {
            var entity = await _repository.GetByReasonAsync(reason);
            if (entity == null)
                throw new InvalidOperationException($"A PosVoid with the Reason '{reason}' does not exist.");
            entity.UpdateConfirmation(id ,voidedById, voidedByName, reason);
            await _repository.UpdateAsync(entity);
            return true;
        }
        public async Task<bool> Delete(string reason)
        {
            var entity = await _repository.GetByReasonAsync(reason);
            if (entity == null)
                return false;
            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}