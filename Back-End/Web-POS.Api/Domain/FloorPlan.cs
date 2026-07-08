using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("FloorPlan")]
    public class FloorPlan : ISyncableEntity
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        public string Name { get; private set; }
        public string Color { get; private set; }

        // Public set required by ISyncableEntity — stamped by DbContext, never by call sites.
        public DateTime LastModified { get; set; } = DateTime.UtcNow;

        public FloorPlan() { }

        private FloorPlan(int companyId, string name, string color)
        {
            CompanyId = companyId;
            Name = name;
            Color = color;
        }

        public static FloorPlan Create(int companyId, string name, string color = "Transparent")
        {
            return new FloorPlan(companyId, name, color);
        }
        public void Update(string name, string color)
        {
            Name = name;
            Color = color;
        }
    }
}