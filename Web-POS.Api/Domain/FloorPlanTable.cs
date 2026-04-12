using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("FloorPlanTable")]
    public class FloorPlanTable
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public int FloorPlanId { get; private set; }

        [MaxLength(100)]
        public string Name { get; private set; }

        public double PositionX { get; private set; }
        public double PositionY { get; private set; }
        public double Width { get; private set; }
        public double Height { get; private set; }
        public bool IsRound { get; private set; }

        public int Status { get; private set; }

        [ForeignKey(nameof(FloorPlanId))]
        public virtual FloorPlan? FloorPlan { get; private set; }

        public FloorPlanTable() { }

        private FloorPlanTable(int companyId, int floorPlanId, string name, double positionX, double positionY, double width, double height, bool isRound)
        {
            CompanyId = companyId;
            FloorPlanId = floorPlanId;
            Name = name;
            PositionX = positionX;
            PositionY = positionY;
            Width = width;
            Height = height;
            IsRound = isRound;
            Status = 0; 
        }

        public static FloorPlanTable Create(int companyId, int floorPlanId, string name, double positionX, double positionY, double width, double height, bool isRound)
        {
            if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Table name is required.");
            return new FloorPlanTable(companyId, floorPlanId, name, positionX, positionY, width, height, isRound);
        }

        public void UpdateGeometry(double positionX, double positionY, double width, double height)
        {
            PositionX = positionX;
            PositionY = positionY;
            Width = width;
            Height = height;
        }

        public void Rename(string newName)
        {
            Name = newName;
        }

        public void UpdateStatus(int status)
        {
            if (status < 0 || status > 2) throw new ArgumentException("Invalid table status.");
            Status = status;
        }
    }
}