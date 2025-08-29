using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sales.Api.Domain
{
    [Table("FloorPlanTable")]
    public class FloorPlanTable
    {
        [Key]
        public int Id { get; set; }
        public string Name { get; set; }
        public int FloorPlanId { get; set; }
        public double PositionX { get; set; }
        public double PositionY { get; set; }
        public double Width { get; set; }
        public double Height { get; set; }
        public bool IsRound { get; set; }

        [ForeignKey(nameof(FloorPlanId))]
        public virtual FloorPlan FloorPlan { get; set; }

        private FloorPlanTable(string name, int floorPlanId, double width, double height)
        {
            Name = name;
            FloorPlanId = floorPlanId;
            Width = width;
            Height = height;
        }

        public FloorPlanTable() { }

        public static FloorPlanTable Create(string name, int floorPlanId, double width, double height)
        {
            return new FloorPlanTable(name, floorPlanId, width, height);
        }

        public void Update(string name, double positionX, double positionY, double width, double height, bool isRound)
        {
            Name = name;
            PositionX = positionX;
            PositionY = positionY;
            Width = width;
            Height = height;
            IsRound = isRound;
        }
    }
}