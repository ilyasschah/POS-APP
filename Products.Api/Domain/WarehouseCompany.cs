using Products.Api.Domain;
using System.ComponentModel.DataAnnotations.Schema;

[Table("WarehouseCompany")]
public class WarehouseCompany
{
    public int CompanyId { get; set; }
    public int WarehouseId { get; set; }

    // navs (optional)
    public Company? Company { get; set; }
    public Warehouse? Warehouse { get; set; }
}
