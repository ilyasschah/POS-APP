using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PaymentTypeService
    {
        public readonly PaymentTypeRepository _repository;

        public PaymentTypeService(PaymentTypeRepository repository)
        {
            _repository = repository;
        }

        public async Task<PaymentTypeDto> CreateAsync(CreatePaymentTypeRequest req, int companyId)
        {
            var existingByName = await _repository.GetByNameAsync(req.Name, companyId);
            if (existingByName != null)
            {
                throw new InvalidOperationException($"A payment type with the name '{req.Name}' already exists.");
            }

            var newpaymentType = PaymentType.Create(
                companyId,
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

            await _repository.AddAsync(newpaymentType);
            return new PaymentTypeDto
            {
                Id = newpaymentType.Id,
                CompanyId = companyId,
                Name = newpaymentType.Name,
                Code = newpaymentType.Code,
                IsCustomerRequired = newpaymentType.IsCustomerRequired,
                IsFiscal = newpaymentType.IsFiscal,
                IsSlipRequired = newpaymentType.IsSlipRequired,
                IsChangeAllowed = newpaymentType.IsChangeAllowed,
                Ordinal = newpaymentType.Ordinal,
                IsEnabled = newpaymentType.IsEnabled,
                IsQuickPayment = newpaymentType.IsQuickPayment,
                OpenCashDrawer = newpaymentType.OpenCashDrawer,
                ShortcutKey = newpaymentType.ShortcutKey,
                MarkAsPaid = newpaymentType.MarkAsPaid
            };
        }

        public async Task<bool> Update(UpdatePaymentTypeRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId);
            if (entity == null)
            {
                return false;
            }
            var existingByName = await _repository.GetByNameAsync(req.Name, companyId);
            if (existingByName != null && existingByName.Id != req.Id)
            {
                throw new InvalidOperationException($"Another payment type with the name '{req.Name}' already exists.");
            }
            entity.Name = req.Name ?? entity.Name;
            entity.Code = req.Code ?? entity.Code;
            entity.ShortcutKey = req.ShortcutKey ?? entity.ShortcutKey;
            entity.IsCustomerRequired = req.IsCustomerRequired ?? entity.IsCustomerRequired;
            entity.IsFiscal = req.IsFiscal ?? entity.IsFiscal;
            entity.IsSlipRequired = req.IsSlipRequired ?? entity.IsSlipRequired;
            entity.IsChangeAllowed = req.IsChangeAllowed ?? entity.IsChangeAllowed;
            entity.Ordinal = req.Ordinal ?? entity.Ordinal;
            entity.IsEnabled = req.IsEnabled ?? entity.IsEnabled;
            entity.IsQuickPayment = req.IsQuickPayment ?? entity.IsQuickPayment;
            entity.OpenCashDrawer = req.OpenCashDrawer ?? entity.OpenCashDrawer;
            entity.MarkAsPaid = req.MarkAsPaid ?? entity.MarkAsPaid;

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entityToDelete = await _repository.GetByIdAsync(id, companyId);
            if (entityToDelete == null) return false;
            await _repository.DeleteAsync(id, companyId);
            return true;
        }
    }
}