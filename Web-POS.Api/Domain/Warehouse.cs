using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Warehouse")]
    public class Warehouse
    {
        [Key]
        public int Id { get; set; }
        public string? Name { get; set; }
        public WarehouseCompany? Mapping { get; set; }
        private Warehouse(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("Name must not be null or whitespace.", nameof(name));
            }
            Name = name;
        }
        public Warehouse() { }
        public static Warehouse Create(string name)
        {
            return new Warehouse(name);
        }
    }
}
