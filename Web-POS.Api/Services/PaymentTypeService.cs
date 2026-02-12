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

        public async Task<PaymentType> Create(CreatePaymentTypeRequest req, int companyId)
        {
            if (await _repository.ExistsbyNameAsync(req.Name, companyId))
            {
                throw new InvalidOperationException($"A payment type with the name '{req.Name}' already exists.");
            }

            var entity = PaymentType.Create(
                name: req.Name,
                code:req.Code,
                iscustomerrequired: req.IsCustomerRequired, 
                isfiscal:req.IsFiscal,
                issliprequired:req.IsSlipRequired,
                ischnageallowed: req.IsChangeAllowed, 
                ordinal:req.Ordinal,
                isenabled:req.IsEnabled, 
                isquickpayment:req.IsQuickPayment, 
                opencashdrawer:req.OpenCashDrawer,
                shortcutkey:req.ShortcutKey, 
                markaspaid:req.MarkAsPaid
            );
            entity.CompanyId = companyId;

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdatePaymentTypeRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId, trackEntity: true);
            if (entity == null)
            {
                return false;
            }
            var existingByName = await _repository.GetByNameAsync(req.Name, companyId);
            if (existingByName != null && existingByName.Id != id)
            {
                throw new InvalidOperationException($"Another payment type with the name '{req.Name}' already exists.");
            }
            if (req.Name != null) entity.Name = req.Name;
            if (req.Code != null) entity.Code = req.Code;
            if (req.ShortcutKey != null) entity.ShortcutKey = req.ShortcutKey;

            entity.IsCustomerRequired = req.IsCustomerRequired;
            entity.IsFiscal = req.IsFiscal;
            entity.IsSlipRequired = req.IsSlipRequired;
            entity.IsChangeAllowed = req.IsChangeAllowed;
            entity.Ordinal = req.Ordinal;
            entity.IsEnabled = req.IsEnabled;
            entity.IsQuickPayment = req.IsQuickPayment;
            entity.OpenCashDrawer = req.OpenCashDrawer;
            entity.MarkAsPaid = req.MarkAsPaid;

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entityToDelete = await _repository.GetByIdAsync(id, companyId, trackEntity: true);
            if (entityToDelete == null)
                return false;
            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}