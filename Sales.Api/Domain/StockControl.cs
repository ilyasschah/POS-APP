using Products.Api.Domain;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sales.Api.Domain;

[Table("StockControl")]
public class StockControl
{
    [Key]
    public int Id { get; private set; }
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

    // Private constructor for the static Create method
    private StockControl(int productId)
    {
        ProductId = productId;
        IsLowStockWarningEnabled = true; // Default value
    }
    
    // Public parameterless constructor for EF Core
    public StockControl() { }

    public static StockControl Create(int productId)
    {
        if (productId <= 0)
            throw new ArgumentException("ProductId must be valid.", nameof(productId));

        return new StockControl(productId);
    }

    public void Update(int? customerId, decimal reorderPoint, decimal preferredQuantity, bool isLowStockWarningEnabled, decimal lowStockWarningQuantity)
    {
        CustomerId = customerId;
        ReorderPoint = reorderPoint;
        PreferredQuantity = preferredQuantity;
        IsLowStockWarningEnabled = isLowStockWarningEnabled;
        LowStockWarningQuantity = lowStockWarningQuantity;
    }
}
