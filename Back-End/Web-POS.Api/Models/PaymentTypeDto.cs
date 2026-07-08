namespace Api.Models
{
    public class PaymentTypeDto
    {
        public int Id { get; set; }
        public int? CompanyId { get; set; }
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
    }

    public class CreatePaymentTypeRequest
    {
        public required string Name { get; set; }
        public string? Code { get; set; }
        public bool IsCustomerRequired { get; set; }
        public bool IsFiscal { get; set; }
        public bool IsSlipRequired { get; set; }
        public bool IsChangeAllowed { get; set; }
        public int  Ordinal { get; set; }
        public bool  IsEnabled { get; set; }
        public bool  IsQuickPayment { get; set; }
        public bool  OpenCashDrawer { get; set; }
        public string?  ShortcutKey { get; set; }
        public bool  MarkAsPaid { get; set; }
    }

    public class UpdatePaymentTypeRequest
    {
        public int Id { get; set; }
        public string? Name { get; set; }
        public string? Code { get; set; }
        public string? ShortcutKey { get; set; }
        public bool? IsCustomerRequired { get; set; }
        public bool? IsFiscal { get; set; }
        public bool? IsSlipRequired { get; set; }
        public bool? IsChangeAllowed { get; set; }
        public int? Ordinal { get; set; }
        public bool? IsEnabled { get; set; }
        public bool? IsQuickPayment { get; set; }
        public bool? OpenCashDrawer { get; set; }
        public bool? MarkAsPaid { get; set; }
    }
}