using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Warehouse")]
    public class Warehouse
    {
        [Key]
        public int Id { get; private set; }

        [Required]
        public string Name { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; private set; }

        private Warehouse(int companyId, string name)
        {
            if (companyId <= 0)
                throw new ArgumentException("Invalid CompanyId", nameof(companyId));
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name must not be empty.", nameof(name));

            CompanyId = companyId;
            Name = name.Trim();
        }

        public Warehouse() { }

        public static Warehouse Create(int companyId, string name)
        {
            return new Warehouse(companyId, name);
        }

        public void UpdateName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name must not be empty.", nameof(name));

            Name = name.Trim();
        }
    }
}