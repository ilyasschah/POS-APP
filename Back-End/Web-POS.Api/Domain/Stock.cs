using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Stock")]
    public class Stock
    {
        [Key]
        public int Id { get; set; }
        public decimal Quantity { get; set; }
        public int WarehouseId { get; set; }

        [ForeignKey("WarehouseId")]
        public virtual Warehouse? Warehouse { get; set; }
        public int ProductId { get; set; }
        [ForeignKey("ProductId")]
        public virtual Product? Product { get; set; }
        public int CompanyId { get; set; }
        [ForeignKey("CompanyId")]
        public virtual Company? Company { get; set; }
        private Stock(
            decimal quantity, 
            int warehouseid, 
            int productid,
            int companyid)
        {
            Quantity = quantity;
            WarehouseId = warehouseid;
            ProductId = productid;
            CompanyId = companyid;
        }
        public Stock() { }
        public static Stock Create(
            decimal quantity, 
            int warehouseid, 
            int productid,
            int companyid)
        
            => new Stock(
                quantity, 
                warehouseid, 
                productid, 
                companyid);

        public void UpdateDetails(decimal quantity, int warehouseId, int productId)
        {
            Quantity = quantity;

            if (WarehouseId != warehouseId)
            {
                WarehouseId = warehouseId;
                Warehouse = null;
            }

            if (ProductId != productId)
            {
                ProductId = productId;
                Product = null;
            }
        }
    }
}
