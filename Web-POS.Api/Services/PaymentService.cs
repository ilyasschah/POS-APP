using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PaymentService
    {
        public readonly PaymentRepository _repository;

        public PaymentService(PaymentRepository repository)
        {
            _repository = repository;
        }

        public async Task<Payment> Create(CreatePaymentRequest req, int companyId)
        {
            var newPayment = Payment.Create(
                req.DocumentId,
                req.PaymentTypeId,
                req.Amount,
                req.UserId
            );

            newPayment.Date = req.Date;

            await _repository.AddAsync(newPayment);
            return newPayment;
        }

        public async Task<bool> Update(int id, UpdatePaymentRequest req, int companyId)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A payment with the ID '{id}' was not found.");
            }

            entityToUpdate.Update(req.Amount, req.Date);
            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
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