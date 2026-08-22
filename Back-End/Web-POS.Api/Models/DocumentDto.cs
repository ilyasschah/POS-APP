namespace Api.Models
{
    public class DocumentDto
    {
        public int Id { get; set; }
        public string Number { get; set; } = string.Empty;
        public int UserId { get; set; }
        public string? UserName { get; set; }
        public int? CustomerId { get; set; }
        public string? CustomerName { get; set; }
        public int CompanyId { get; set; }
        public string? CompanyName { get; set; }
        public int DocumentTypeId { get; set; }
        public string? DocumentTypeName { get; set; }
        public int WarehouseId { get; set; }
        public string? WarehouseName { get; set; }
        public string? OrderNumber { get; set; }
        public DateTime Date { get; set; }
        public DateTime StockDate { get; set; }
        public decimal Total { get; set; }
        public string? ReferenceDocumentNumber { get; set; }
        public DateTime DateCreated { get; set; }
        public DateTime DateUpdated { get; set; }
        public string? InternalNote { get; set; }
        public string? Note { get; set; }
        public DateTime? DueDate { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int PaidStatus { get; set; }
        public bool DiscountApplyRule { get; set; }
        public int ServiceType { get; set; }
    }

    public class CreateDocumentRequest
    {
        public required string Number { get; set; }
        public required int UserId { get; set; }
        public int? CustomerId { get; set; }
        public string? OrderNumber { get; set; }
        public DateTime? Date { get; set; }
        public DateTime? StockDate { get; set; }
        public required decimal Total { get; set; }
        public bool? IsClockedOut { get; set; }
        public required int DocumentTypeId { get; set; }
        public required int WarehouseId { get; set; }
        public string? ReferenceDocumentNumber { get; set; }
        public string? InternalNote { get; set; }
        public string? Note { get; set; }
        public DateTime? DueDate { get; set; }
        public decimal? Discount { get; set; }
        public int? DiscountType { get; set; }
        public int? PaidStatus { get; set; }
        public bool? DiscountApplyRule { get; set; }
        public int? ServiceType { get; set; }
    }

    public class UpdateDocumentRequest
    {
        public required int Id { get; set; }
        public string? Number { get; set; }
        public int? CustomerId { get; set; }
        public DateTime? Date { get; set; }
        public DateTime? StockDate { get; set; }
        public decimal? Total { get; set; }
        public bool? IsClockedOut { get; set; }
        public int? DocumentTypeId { get; set; }
        public int? WarehouseId { get; set; }
        public string? ReferenceDocumentNumber { get; set; }
        public string? InternalNote { get; set; }
        public string? Note { get; set; }
        public DateTime? DueDate { get; set; }
        public int? PaidStatus { get; set; }
        public bool? DiscountApplyRule { get; set; }
        public decimal? Discount { get; set; }
    }
}