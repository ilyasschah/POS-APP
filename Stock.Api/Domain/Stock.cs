using Products.Api.Domain;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Stocks.Api.Domain
{
    [Table("Stock")]
    public class Stock
    {
        [Key]
        public int Id { get; set; }
        public decimal Quantity { get; set; }
        public int WarehouseId { get; set; }
        [ForeignKey(nameof(WarehouseId))]
        public virtual Warehouse Warehouse { get; set; }
        public int ProductId { get; set; }
        [ForeignKey("ProductId")]
        public virtual Product Product { get; set; }

        private Stock(decimal quantity, int warehouseid, int productid)
        {
            Quantity = quantity;
            WarehouseId = warehouseid;
            ProductId = productid;
        }
        public Stock() { }
        public static Stock Create(decimal quantity, int warehouseid, int productid)
        {
            if (quantity < 0)
                throw new ArgumentException("Quantity cannot be negative", nameof(quantity));
            if (warehouseid < 0)
                throw new ArgumentException("WarehouseId must be greater than zero", nameof(warehouseid));
            return new Stock(quantity, warehouseid, productid);
        }
        public void Update(decimal newQuantity, int newWarehouseId, int newProductid)
        {
            if (newQuantity < 0)
                throw new ArgumentException("Quantity cannot be negative", nameof(newQuantity));
            if (newWarehouseId <= 0)
                throw new ArgumentException("WarehouseId must be greater than zero", nameof(newWarehouseId));
            Quantity = newQuantity;
            WarehouseId = newWarehouseId;
            ProductId = newProductid;
        }
    }
}
