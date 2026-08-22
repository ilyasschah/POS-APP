using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Document")]
    public class Document
    {
        [Key]
        public int Id { get; private set; }
        public string Number { get; private set; } = default!;
        public int UserId { get; private set; }
        public int? CustomerId { get; private set; }
        public int CompanyId { get; private set; }
        public string? OrderNumber { get; private set; }
        public DateTime Date { get; private set; }
        public DateTime StockDate { get; private set; }
        public decimal Total { get; private set; }
        public bool IsClockedOut { get; private set; }
        public int DocumentTypeId { get; private set; }
        public int WarehouseId { get; private set; }
        public string? ReferenceDocumentNumber { get; private set; }
        public DateTime DateCreated { get; private set; }
        public DateTime DateUpdated { get; private set; }

        /// <summary>
        /// The POS session this belongs to. Nullable — every existing write
        /// path leaves it null, so nothing that works today changes.
        /// </summary>
        public int? SessionId { get; private set; }

        /// <summary>
        /// True when this document reached the server after its session had
        /// already been closed and reported — an offline register reconnecting.
        /// The sale is kept and keeps its session; this is what makes the late
        /// arrival visible rather than silently absorbed.
        /// </summary>
        public bool ArrivedAfterClose { get; private set; }

        /// <summary>Sets the session at creation/sync time.</summary>
        public void AttachToSession(int? sessionId, bool arrivedAfterClose = false)
        {
            SessionId = sessionId;
            if (arrivedAfterClose) ArrivedAfterClose = true;
        }
        public string? InternalNote { get; private set; }
        public string? Note { get; private set; }
        public DateTime? DueDate { get; private set; }
        public decimal Discount { get; private set; }
        public int DiscountType { get; private set; }
        public int PaidStatus { get; private set; }
        public bool DiscountApplyRule { get; private set; }
        public int ServiceType { get; private set; }

        [ForeignKey(nameof(UserId))]
        public virtual User? User { get; private set; }

        [ForeignKey(nameof(CustomerId))]
        public virtual Customer? Customer { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        [ForeignKey(nameof(DocumentTypeId))]
        public virtual DocumentType? DocumentType { get; private set; }

        [ForeignKey(nameof(WarehouseId))]
        public virtual Warehouse? Warehouse { get; private set; }

        private Document(
            string number,
            int userId,
            int? customerId,
            string? orderNumber,
            DateTime? date,
            DateTime? stockDate,
            decimal total,
            bool isClockedOut,
            int documentTypeId,
            int warehouseId,
            string? referenceDocumentNumber,
            string? internalNote,
            string? note,
            DateTime? dueDate,
            decimal discount,
            int discountType,
            int paidStatus,
            bool discountApplyRule,
            int companyId,
            int serviceType)
        {
            Number = number;
            UserId = userId;
            CustomerId = customerId;
            OrderNumber = orderNumber;
            Date = date ?? DateTime.UtcNow.Date;
            StockDate = stockDate ?? DateTime.UtcNow;
            Total = total;
            IsClockedOut = isClockedOut;
            DocumentTypeId = documentTypeId;
            WarehouseId = warehouseId;
            DateCreated = DateTime.UtcNow;
            DateUpdated = DateTime.UtcNow;
            ReferenceDocumentNumber = referenceDocumentNumber;
            InternalNote = internalNote;
            Note = note;
            DueDate = dueDate;
            Discount = discount;
            DiscountType = discountType;
            PaidStatus = paidStatus;
            DiscountApplyRule = discountApplyRule;
            CompanyId = companyId;
            ServiceType = serviceType;
        }

        public Document() { }

        public static Document Create(
            string number,
            int userId,
            int companyId,
            int documentTypeId,
            int warehouseId,
            decimal total,
            int? customerId = null, 
            string? orderNumber = null,
            DateTime? date = null,
            DateTime? stockDate = null,
            bool isClockedOut = false,
            string? referenceDocumentNumber = null,
            string? internalNote = null,
            string? note = null,
            DateTime? dueDate = null,
            decimal discount = 0,
            int discountType = 0,
            int paidStatus = 0,
            bool discountApplyRule = false,
            int serviceType = 0)
        {
            return new Document(
                number, userId, customerId, orderNumber, date, stockDate, total,
                isClockedOut, documentTypeId, warehouseId, referenceDocumentNumber,
                internalNote, note, dueDate, discount, discountType, paidStatus,
                discountApplyRule, companyId, serviceType
            );
        }

        public void UpdateDetails(
            string number,
            string? referenceDocumentNumber,
            int? customerId,
            decimal total,
            int paidStatus,
            DateTime? date,
            DateTime? dueDate,
            DateTime? stockDate,
            decimal discount,
            int? warehouseId,
            string? internalNote,
            string? note,
            bool discountApplyRule)
        {
            Number = number;
            ReferenceDocumentNumber = referenceDocumentNumber;
            PaidStatus = paidStatus;
            Date = date ?? Date;
            DueDate = dueDate ?? DueDate;
            StockDate = stockDate ?? StockDate;
            Discount = discount;
            InternalNote = internalNote;
            Note = note;
            DiscountApplyRule = discountApplyRule;
            DateUpdated = DateTime.UtcNow;
            Total = total;
            if (CustomerId != customerId)
            {
                CustomerId = customerId;
                Customer = null;
            }

            if (warehouseId.HasValue && WarehouseId != warehouseId.Value)
            {
                WarehouseId = warehouseId.Value;
                Warehouse = null;
            }
        }
    }
}