using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Warehouse")]
    public class Warehouse
    {
        [Key]
        public int Id { get;  set; }
        public string Name { get;  set; } = default!;
        public int CompanyId { get;  set; }
        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; set; }
        private Warehouse(int companyId, string name)
        {
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
            Name = name.Trim();
        }
    }
}