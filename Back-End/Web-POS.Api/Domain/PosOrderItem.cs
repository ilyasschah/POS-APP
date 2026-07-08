using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("PosOrderItem")]
    public class PosOrderItem
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }

        public int PosOrderId { get; private set; }
        public int ProductId { get; private set; }
        public int RoundNumber { get; private set; }
        public decimal Quantity { get; private set; }
        public decimal Price { get; private set; }
        public bool IsLocked { get; private set; }
        public decimal Discount { get; private set; }
        public int DiscountType { get; private set; }
        public bool IsFeatured { get; private set; }
        public int? VoidedBy { get; private set; }
        public string? Comment { get; private set; }
        public DateTime DateCreated { get; private set; }
        public string? Bundle { get; private set; }
        public int DiscountAppliedType { get; private set; }

        [ForeignKey("PosOrderId")]
        public virtual PosOrder PosOrder { get; private set; }

        [ForeignKey("ProductId")]
        public virtual Product Product { get; private set; }

        [ForeignKey("VoidedBy")]
        public virtual User? VoidedByUser { get; private set; }

        public PosOrderItem() { }

        private PosOrderItem(int companyId, int posOrderId, int productId, int roundNumber, decimal quantity, decimal price, decimal discount, int discountType, int discountAppliedType, string? comment, string? bundle)
        {
            CompanyId = companyId;
            PosOrderId = posOrderId;
            ProductId = productId;
            RoundNumber = roundNumber;
            Quantity = quantity;
            Price = price;
            Discount = discount;
            DiscountType = discountType;
            DiscountAppliedType = discountAppliedType;
            Comment = comment;
            Bundle = bundle;
            DateCreated = DateTime.UtcNow;
            IsLocked = false;
            IsFeatured = false;
            VoidedBy = null;
        }

        public static PosOrderItem Create(int companyId, int posOrderId, int productId, int roundNumber, decimal quantity, decimal price, decimal discount, int discountType, int discountAppliedType, string? comment, string? bundle)
        {
            if (companyId <= 0) throw new ArgumentException("Company ID must be valid.", nameof(companyId));
            if (quantity <= 0) throw new ArgumentException("Quantity must be positive.", nameof(quantity));
            if (price < 0) throw new ArgumentException("Price cannot be negative.", nameof(price));

            return new PosOrderItem(companyId, posOrderId, productId, roundNumber, quantity, price, discount, discountType, discountAppliedType, comment, bundle);
        }

        public void UpdateDetails(decimal quantity, decimal price, decimal discount, int discountType, int discountAppliedType, string? comment)
        {
            if (IsLocked)
                throw new InvalidOperationException("This item is locked because it has already been sent to the kitchen. Please void it to make changes."); 
            if (quantity <= 0) throw new ArgumentException("Quantity must be positive.", nameof(quantity));
            if (price < 0) throw new ArgumentException("Price cannot be negative.", nameof(price));

            Quantity = quantity;
            Price = price;
            Discount = discount;
            DiscountType = discountType;
            DiscountAppliedType = discountAppliedType;
            Comment = comment;
        }

        public void LockItem()
        {
            IsLocked = true;
        }

        public void VoidItem(int voidedById)
        {
            VoidedBy = voidedById;
        }
    }
}