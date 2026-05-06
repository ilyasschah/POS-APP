using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
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
        public int ServiceType { get; set; }
        public int ServiceStatus { get; set; }
        public int? FloorPlanTableId { get; set; }

        [ForeignKey(nameof(UserId))]
        public virtual User? User { get; set; }

        [ForeignKey(nameof(CustomerId))]
        public virtual Customer? Customer { get; set; }

        public PosOrder() { }

        private PosOrder(int companyId, int userId, string number, decimal discount, int discountType, decimal? total, int? customerId, int serviceType, int serviceStatus, int? floorPlanTableId)
        {
            CompanyId = companyId;
            UserId = userId;
            Number = number;
            Discount = discount;
            DiscountType = discountType;
            Total = total;
            CustomerId = customerId;
            ServiceType = serviceType;

            ServiceStatus = serviceStatus;
            FloorPlanTableId = floorPlanTableId;
        }

        public static PosOrder Create(int companyId, int userId, string number, decimal discount, int discountType, decimal? total, int? customerId, int serviceType, int serviceStatus, int? floorPlanTableId = null)
        {
            if (companyId <= 0) throw new ArgumentException("Company ID must be valid.", nameof(companyId));
            if (userId <= 0) throw new ArgumentException("User ID must be valid.", nameof(userId));
            if (string.IsNullOrWhiteSpace(number)) throw new ArgumentException("Order number cannot be empty.", nameof(number));

            return new PosOrder(companyId, userId, number, discount, discountType, total, customerId, serviceType, serviceStatus, floorPlanTableId);
        }

        public void Update(int userId, string number, decimal discount, int discountType, decimal? total, int? customerId, int serviceType, int serviceStatus, int? floorPlanTableId)
        {
            if (userId <= 0) throw new ArgumentException("User ID must be valid.", nameof(userId));
            if (string.IsNullOrWhiteSpace(number)) throw new ArgumentException("Order number cannot be empty.", nameof(number));

            UserId = userId;
            Number = number;
            Discount = discount;
            DiscountType = discountType;
            Total = total;
            CustomerId = customerId;
            ServiceType = serviceType;
            ServiceStatus = serviceStatus;
            FloorPlanTableId = floorPlanTableId;
        }
    }
}