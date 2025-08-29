using Sales.Api.Domain;
using Stocks.Api.Domain;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Xml.Linq;

namespace Documents.Api.Domain
{
    [Table("Document")]
    public class Document
    {
        [Key]
        public int Id { get; set; }
        public string Number { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public string? OrderNumber { get; set; }
        public DateTime Date { get; set; }
        public DateTime StockDate { get; set; }
        public decimal Total { get; set; }
        public bool IsClockedOut { get; set; }
        public int DocumentTypeId { get; set; }
        public int WarehouseId { get; set; }
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

        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }

        [ForeignKey(nameof(CustomerId))]
        public virtual Customer? Customer { get; set; }

        [ForeignKey(nameof(DocumentTypeId))]
        public virtual DocumentType DocumentType { get; set; }

        [ForeignKey(nameof(WarehouseId))]
        public virtual Warehouse Warehouse { get; set; }

        private Document(string number, int userId, int documentTypeId, int warehouseId, decimal total)
        {
            Number = number;
            UserId = userId;
            DocumentTypeId = documentTypeId;
            WarehouseId = warehouseId;
            Total = total;
            Date = DateTime.UtcNow.Date;
            StockDate = DateTime.UtcNow;
            DateCreated = DateTime.UtcNow;
            DateUpdated = DateTime.UtcNow;
        }

        public Document() { }

        public static Document Create(string number, int userId, int documentTypeId, int warehouseId, decimal total)
        {
            return new Document(number, userId, documentTypeId, warehouseId, total);
        }

        public void Update(string number, int? customerId, decimal total, string? note, int paidStatus)
        {
            Number = number;
            CustomerId = customerId;
            Total = total;
            Note = note;
            PaidStatus = paidStatus;
            DateUpdated = DateTime.UtcNow;
        }
    }
}