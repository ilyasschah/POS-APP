using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("StockControl")]
    public class StockControl
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public int ProductId { get; private set; }
        public int? CustomerId { get; private set; }
        public decimal ReorderPoint { get; private set; }
        public decimal PreferredQuantity { get; private set; }
        public bool IsLowStockWarningEnabled { get; private set; }
        public decimal LowStockWarningQuantity { get; private set; }

        [ForeignKey(nameof(ProductId))]
        public virtual Product Product { get; private set; }

        [ForeignKey(nameof(CustomerId))]
        public virtual Customer Customer { get; private set; }

        public StockControl() { }

        private StockControl(int productId, int companyId)
        {
            ProductId = productId;
            CompanyId = companyId;
            IsLowStockWarningEnabled = true;
        }

        public static StockControl Create(int productId, int companyId)
        {
            if (productId <= 0) throw new ArgumentException("ProductId must be valid.", nameof(productId));
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));

            return new StockControl(productId, companyId);
        }

        public void Update(int? customerId, decimal? reorderPoint, decimal? preferredQuantity, bool? isLowStockWarningEnabled, decimal? lowStockWarningQuantity)
        {
            if (customerId.HasValue) CustomerId = customerId.Value == 0 ? null : customerId.Value;

            if (reorderPoint.HasValue) ReorderPoint = reorderPoint.Value;
            if (preferredQuantity.HasValue) PreferredQuantity = preferredQuantity.Value;
            if (isLowStockWarningEnabled.HasValue) IsLowStockWarningEnabled = isLowStockWarningEnabled.Value;
            if (lowStockWarningQuantity.HasValue) LowStockWarningQuantity = lowStockWarningQuantity.Value;
        }
    }
}