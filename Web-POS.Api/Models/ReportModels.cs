namespace Api.Models
{
    public class SalesByProductDto
    {
        public string? Code { get; set; }
        public string Product { get; set; } = "";
        public decimal Quantity { get; set; }
        public string UOM { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesByProductGroupDto
    {
        public string ProductGroup { get; set; } = "";
        public decimal Quantity { get; set; }
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesByCustomerDto
    {
        public string Customer { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesByTaxDto
    {
        public string TaxName { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesByUserDto
    {
        public string User { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesByPaymentTypeDto
    {
        public DateTime Date { get; set; }
        public string PaymentTypeName { get; set; } = "";
        public decimal Amount { get; set; }
    }

    public class PaymentTypesByUserDto
    {
        public string UserName { get; set; } = "";
        public string PaymentTypeName { get; set; } = "";
        public decimal Amount { get; set; }
    }

    public class PaymentTypesByCustomerDto
    {
        public string CustomerName { get; set; } = "";
        public string PaymentTypeName { get; set; } = "";
        public decimal Amount { get; set; }
    }

    public class RefundItemListDto
    {
        public string? CustomerCode { get; set; }
        public string CustomerName { get; set; } = "";
        public string DocumentNumber { get; set; } = "";
        public string? RefNumber { get; set; }
        public DateTime Date { get; set; }
        public DateTime DateCreated { get; set; }
        public string? OrderNumber { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal Quantity { get; set; }
        public string UOM { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal TotalTax { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesItemListDto
    {
        public string DocumentTypeName { get; set; } = "";
        public DateTime Date { get; set; }
        public DateTime DateCreated { get; set; }
        public string DocumentNumber { get; set; } = "";
        public string? RefNumber { get; set; }
        public string? CustomerCode { get; set; }
        public string CustomerName { get; set; } = "";
        public string? OrderNumber { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal Quantity { get; set; }
        public string UOM { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal TotalTax { get; set; }
        public decimal Total { get; set; }
    }

    public class InvoiceListDto
    {
        public DateTime Date { get; set; }
        public string DocumentNumber { get; set; } = "";
        public string CustomerName { get; set; } = "";
        public string PaymentMethodName { get; set; } = "";
        public decimal Total { get; set; }
    }

    public class DailySalesDto
    {
        public DateTime Date { get; set; }
        public decimal Total { get; set; }
    }

    public class HourlySalesDto
    {
        public int Hour { get; set; }
        public decimal TotalSales { get; set; }
        public int SalesCount { get; set; }
    }

    public class HourlySalesByGroupDto
    {
        public string ProductGroup { get; set; } = "";
        public int Hour { get; set; }
        public decimal Total { get; set; }
    }

    public class SalesByTableDto
    {
        public string OrderNumber { get; set; } = "";
        public int NumberOfSales { get; set; }
        public decimal Total { get; set; }
    }

    public class ProfitDto
    {
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal Quantity { get; set; }
        public decimal Cost { get; set; }
        public decimal Total { get; set; }
    }

    public class UnpaidSalesDto
    {
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public DateTime? DueDate { get; set; }
        public string CustomerName { get; set; } = "";
        public decimal DocumentTotal { get; set; }
        public decimal TotalPaid { get; set; }
        public decimal TotalUnpaid { get; set; }
    }

    public class StockMovementDto
    {
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal NumSales { get; set; }
    }

    public class ItemsDiscountsDto
    {
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal TotalDiscount { get; set; }
    }

    public class DiscountsGrantedDto
    {
        public string CustomerName { get; set; } = "";
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public string UserName { get; set; } = "";
        public decimal TotalBeforeDiscount { get; set; }
        public decimal TotalAfterDiscount { get; set; }
        public decimal DiscountGranted { get; set; }
    }

    public class PurchaseByProductDto
    {
        public string? Code { get; set; }
        public string Product { get; set; } = "";
        public decimal Quantity { get; set; }
        public string UOM { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class StockReturnByProductDto
    {
        public DateTime Date { get; set; }
        public string? Code { get; set; }
        public string Product { get; set; } = "";
        public decimal Quantity { get; set; }
        public string UOM { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class LossAndDamageByProductDto
    {
        public DateTime Date { get; set; }
        public string? Code { get; set; }
        public string Product { get; set; } = "";
        public decimal Quantity { get; set; }
        public string UOM { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class PurchaseBySupplierDto
    {
        public string Supplier { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }

    public class UnpaidPurchaseDto
    {
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public DateTime? DueDate { get; set; }
        public string SupplierName { get; set; } = "";
        public decimal DocumentTotal { get; set; }
        public decimal TotalPaid { get; set; }
        public decimal TotalUnpaid { get; set; }
    }

    public class PurchaseDiscountsDto
    {
        public string SupplierName { get; set; } = "";
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public string UserName { get; set; } = "";
        public decimal TotalBeforeDiscount { get; set; }
        public decimal TotalAfterDiscount { get; set; }
        public decimal DiscountGranted { get; set; }
    }

    public class PurchaseByTaxDto
    {
        public string TaxName { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal Total { get; set; }
    }

    public class PurchaseInvoiceListDto
    {
        public DateTime Date { get; set; }
        public string DocumentNumber { get; set; } = "";
        public string? ExternalDocument { get; set; }
        public string SupplierName { get; set; } = "";
        public decimal Total { get; set; }
    }

    public class PurchaseItemsDiscountsDto
    {
        public string SupplierName { get; set; } = "";
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public string UserName { get; set; } = "";
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal Quantity { get; set; }
        public decimal Cost { get; set; }
        public decimal TotalBeforeDiscount { get; set; }
        public decimal TotalAfterDiscount { get; set; }
        public decimal DiscountValue { get; set; }
        public int DiscountType { get; set; }
        public decimal TotalDiscount { get; set; }
    }

    public class PurchaseExpirationDateDto
    {
        public string?  ProductCode    { get; set; }
        public string   ProductName    { get; set; } = "";
        public decimal  Quantity       { get; set; }
        public string   UOM            { get; set; } = "";
        public DateTime ExpirationDate { get; set; }
    }

    public class ReorderProductListDto
    {
        public string  SupplierName  { get; set; } = "N/A";
        public string  ProductName   { get; set; } = "";
        public decimal OrderQuantity { get; set; }
        public string  UOM           { get; set; } = "";
    }

    public class LowStockWarningDto
    {
        public string  SupplierName           { get; set; } = "N/A";
        public string  ProductName            { get; set; } = "";
        public decimal CurrentStock           { get; set; }
        public decimal LowStockWarningQuantity { get; set; }
        public decimal OrderQuantity          { get; set; }
        public string  UOM                   { get; set; } = "";
    }

    public class TransactionHistoryDto
    {
        public DateTime? Date            { get; set; }
        public string    TransactionType { get; set; } = "";
        public string?   RefNumber       { get; set; }
        public decimal   Credit          { get; set; }
        public decimal   Debit           { get; set; }
        public decimal   Balance         { get; set; }
        public bool      IsPreviousBalance { get; set; }
        public string    PartnerName     { get; set; } = "";
    }
}
