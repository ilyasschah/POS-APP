using Products.Api.Domain;
using System.ComponentModel.DataAnnotations.Schema;

[Table("WarehouseCompany")]
public class WarehouseCompany
{
    public int CompanyId { get; set; }
    public int WarehouseId { get; set; }

    // navs (optional)
    [ForeignKey(nameof(CompanyId))]
    public Company? Company { get; set; }
    [ForeignKey(nameof(WarehouseId))]
    public Warehouse? Warehouse { get; set; }

    private WarehouseCompany (int comapanyid , int warehouseid)
    {
        CompanyId = comapanyid;
        WarehouseId = warehouseid;
    }
    public WarehouseCompany() { }
    public static WarehouseCompany Create(int comapanyid, int warehouseid)
    {
        return new WarehouseCompany(comapanyid, warehouseid);
    }
}
