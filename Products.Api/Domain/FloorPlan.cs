using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("FloorPlan")]
    public class FloorPlan
    {
        [Key]
        public int Id { get; set; }
        public string Name { get; set; }
        public string Color { get; set; }

        private FloorPlan(string name, string color)
        {
            Name = name;
            Color = color;
        }

        public FloorPlan() { }

        public static FloorPlan Create(string name, string color = "Transparent")
        {
            return new FloorPlan(name, color);
        }

        public void Update(string name, string color)
        {
            Name = name;
            Color = color;
        }
    }
}