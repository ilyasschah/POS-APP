using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Promotion")]
    public class Promotion
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; }
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public int DaysOfWeek { get; set; }
        public bool IsEnabled { get; set; }

        private Promotion(string name, int daysOfWeek)
        {
            Name = name;
            DaysOfWeek = daysOfWeek;
            IsEnabled = true;
        }

        public Promotion() { }

        public static Promotion Create(string name, int daysOfWeek)
        {
            return new Promotion(name, daysOfWeek);
        }

        public void Update(string name, DateTime? startDate, TimeSpan? startTime, DateTime? endDate, TimeSpan? endTime, int daysOfWeek, bool isEnabled)
        {
            Name = name;
            StartDate = startDate;
            StartTime = startTime;
            EndDate = endDate;
            EndTime = endTime;
            DaysOfWeek = daysOfWeek;
            IsEnabled = isEnabled;
        }
    }
}