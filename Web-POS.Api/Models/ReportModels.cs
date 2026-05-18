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
}
