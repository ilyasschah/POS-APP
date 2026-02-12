using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("PosOrder")]
    public class PosOrder
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int UserId { get; set; }
        public string Number { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal? Total { get; set; }
        public int? CustomerId { get; set; }
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }

        [ForeignKey(nameof(CustomerId))]
        public virtual Customer? Customer { get; set; }

        public PosOrder() { }
        private PosOrder(int userId, string number, decimal discount, int discountType, decimal? total, int? customerId)
        {
            UserId = userId;
            Number = number;
            Discount = discount;
            DiscountType = discountType;
            Total = total;
            CustomerId = customerId;
        }
        public static PosOrder Create(int userId, string number, decimal discount, int discountType, decimal? total, int? customerId)
        {
            if (userId <= 0) throw new ArgumentException("User ID must be valid.", nameof(userId));
            if (string.IsNullOrWhiteSpace(number)) throw new ArgumentException("Order number cannot be empty.", nameof(number));
            return new PosOrder(userId, number, discount, discountType, total, customerId);
        }

        public void Update(int userId, string number, decimal discount, int discountType, decimal? total, int? customerId)
        {
            if (userId <= 0) throw new ArgumentException("User ID must be valid.", nameof(userId));
            if (string.IsNullOrWhiteSpace(number)) throw new ArgumentException("Order number cannot be empty.", nameof(number));

            UserId = userId;
            Number = number;
            Discount = discount;
            DiscountType = discountType;
            Total = total;
            CustomerId = customerId;
        }
    }
}
