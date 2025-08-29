namespace Documents.Api.Models
{
    public class PaymentTypeDto
    {
        public int Id { get; set; }
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
        public bool? IsCustomerRequired { get; set; }
        public bool? IsFiscal { get; set; }
        public bool? IsSlipRequired { get; set; }
        public bool? IsChangeAllowed { get; set; }
        public int? Ordinal { get; set; }
        public bool? IsEnabled { get; set; }
        public bool? IsQuickPayment { get; set; }
        public bool? OpenCashDrawer { get; set; }
        public string? ShortcutKey { get; set; }
        public bool? MarkAsPaid { get; set; }
    }

    public class UpdatePaymentTypeRequest
    {
        public required string Name { get; set; }
        public string? Code { get; set; }
        public required bool IsCustomerRequired { get; set; }
        public required bool IsFiscal { get; set; }
        public required bool IsSlipRequired { get; set; }
        public required bool IsChangeAllowed { get; set; }
        public required int Ordinal { get; set; }
        public required bool IsEnabled { get; set; }
        public required bool IsQuickPayment { get; set; }
        public required bool OpenCashDrawer { get; set; }
        public string? ShortcutKey { get; set; }
        public required bool MarkAsPaid { get; set; }
    }
}