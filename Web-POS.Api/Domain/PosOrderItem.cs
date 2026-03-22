using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("PosOrderItem")]
    public class PosOrderItem
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; set; }
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

        // Foreign Key Navigation Properties
        [ForeignKey("PosOrderId")]
        public virtual PosOrder PosOrder { get; private set; }

        [ForeignKey("ProductId")]
        public virtual Product Product { get; private set; }

        [ForeignKey("VoidedBy")]
        public virtual User VoidedByUser { get; private set; }

        // EF Core Constructor
        public PosOrderItem() { }

        // Private Constructor for Factory Method
        private PosOrderItem(int posOrderId, int productId, int roundNumber, decimal quantity, decimal price, decimal discount, int discountType, string? comment, string? bundle)
        {
            PosOrderId = posOrderId;
            ProductId = productId;
            RoundNumber = roundNumber;
            Quantity = quantity;
            Price = price;
            Discount = discount;
            DiscountType = discountType;
            Comment = comment;
            Bundle = bundle;
            DateCreated = DateTime.UtcNow;
            IsLocked = false;
            IsFeatured = false;
            DiscountAppliedType = 0;
            VoidedBy = null;
        }

        // Static Factory Method
        public static PosOrderItem Create(int posOrderId, int productId, int roundNumber, decimal quantity, decimal price, decimal discount, int discountType, string? comment, string? bundle)
        {
            if (quantity <= 0) throw new ArgumentException("Quantity must be positive.", nameof(quantity));
            if (price < 0) throw new ArgumentException("Price cannot be negative.", nameof(price));

            return new PosOrderItem(posOrderId, productId, roundNumber, quantity, price, discount, discountType, comment, bundle);
        }

        // Public methods to update properties
        public void UpdateDetails(decimal quantity, decimal price, decimal discount, string? comment)
        {
            if (IsLocked) throw new InvalidOperationException("Cannot update a locked order item.");
            Quantity = quantity;
            Price = price;
            Discount = discount;
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



