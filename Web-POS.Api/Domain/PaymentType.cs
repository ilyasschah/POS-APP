using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("PaymentType")]
    public class PaymentType
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; }
        public string? Code { get; set; }
        public bool IsCustomerRequired { get; set; }
        public bool IsFiscal { get; set; }
        public bool IsSlipRequired { get; set; }
        public bool IsChangeAllowed { get; set; }
        public int Ordinal { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsQuickPayment { get; set; }
        public bool OpenCashDrawer { get; set; }
        public string? ShortcutKey { get; set; }
        public bool MarkAsPaid { get; set; }


        public PaymentType() { }
        private PaymentType(string name, string? code, 
            bool iscustomerrequired, bool isfiscal, 
            bool issliprequired, bool ischnageallowed, 
            int ordinal, bool isenabled, 
            bool isquickpayment, bool opencashdrawer, 
            string? shortcutkey, bool markaspaid)
        {
            Name = name;
            Code = code;
            IsCustomerRequired = iscustomerrequired;
            IsFiscal = isfiscal;
            IsSlipRequired = issliprequired;
            IsChangeAllowed = ischnageallowed;
            Ordinal = ordinal;
            IsEnabled = isenabled;
            IsQuickPayment = isquickpayment;
            OpenCashDrawer = opencashdrawer;
            ShortcutKey = shortcutkey;
            MarkAsPaid = markaspaid;
        }
        public static PaymentType Create(
            string name, 
            string? code,
            bool iscustomerrequired, 
            bool isfiscal, 
            bool issliprequired, 
            bool ischnageallowed, 
            int ordinal, 
            bool isenabled, 
            bool isquickpayment, 
            bool opencashdrawer, 
            string? shortcutkey, 
            bool markaspaid)
            => new(name, code, iscustomerrequired, isfiscal, issliprequired, ischnageallowed, 
                ordinal, isenabled, isquickpayment, opencashdrawer, shortcutkey, markaspaid);

        public void Update(
            string name, string? code, bool isCustomerRequired, bool isFiscal,
            bool isSlipRequired, bool isChangeAllowed, int ordinal, bool isEnabled,
            bool isQuickPayment, bool openCashDrawer, string? shortcutKey, bool markAsPaid)
        {
            Name = name;
            Code = code;
            IsCustomerRequired = isCustomerRequired;
            IsFiscal = isFiscal;
            IsSlipRequired = isSlipRequired;
            IsChangeAllowed = isChangeAllowed;
            Ordinal = ordinal;
            IsEnabled = isEnabled;
            IsQuickPayment = isQuickPayment;
            OpenCashDrawer = openCashDrawer;
            ShortcutKey = shortcutKey;
            MarkAsPaid = markAsPaid;
        }
    }
}