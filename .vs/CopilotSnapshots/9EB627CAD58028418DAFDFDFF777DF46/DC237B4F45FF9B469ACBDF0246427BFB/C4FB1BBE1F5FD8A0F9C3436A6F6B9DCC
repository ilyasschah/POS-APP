using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class PaymentTypeService
    {
        public readonly PaymentTypeRepository _repository;

        public PaymentTypeService(PaymentTypeRepository repository)
        {
            _repository = repository;
        }

        public async Task<PaymentType> Create(CreatePaymentTypeRequest req)
        {
            if (await _repository.ExistsAsync(req.Name))
            {
                throw new InvalidOperationException($"A payment type with the name '{req.Name}' already exists.");
            }

            var newPaymentType = PaymentType.Create(req.Name);

            newPaymentType.Code = req.Code;
            newPaymentType.IsCustomerRequired = req.IsCustomerRequired ?? false;
            newPaymentType.IsFiscal = req.IsFiscal ?? true;
            newPaymentType.IsSlipRequired = req.IsSlipRequired ?? false;
            newPaymentType.IsChangeAllowed = req.IsChangeAllowed ?? true;
            newPaymentType.Ordinal = req.Ordinal ?? 0;
            newPaymentType.IsEnabled = req.IsEnabled ?? true;
            newPaymentType.IsQuickPayment = req.IsQuickPayment ?? true;
            newPaymentType.OpenCashDrawer = req.OpenCashDrawer ?? true;
            newPaymentType.ShortcutKey = req.ShortcutKey;
            newPaymentType.MarkAsPaid = req.MarkAsPaid ?? true;

            await _repository.AddAsync(newPaymentType);
            return newPaymentType;
        }

        public async Task<bool> Update(int id, UpdatePaymentTypeRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A payment type with the ID '{id}' was not found.");
            }

            var existingByName = await _repository.GetByNameAsync(req.Name);
            if (existingByName != null && existingByName.Id != id)
            {
                throw new InvalidOperationException($"Another payment type with the name '{req.Name}' already exists.");
            }

            entityToUpdate.Update(
                req.Name, req.Code, req.IsCustomerRequired, req.IsFiscal,
                req.IsSlipRequired, req.IsChangeAllowed, req.Ordinal,
                req.IsEnabled, req.IsQuickPayment, req.OpenCashDrawer,
                req.ShortcutKey, req.MarkAsPaid
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