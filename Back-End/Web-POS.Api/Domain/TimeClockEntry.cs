using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

[Table("TimeClockEntry")]
public class TimeClockEntry : ISyncableEntity
{
    [Key]
    public int Id { get; private set; }

    public int CompanyId { get; private set; }
    public int UserId { get; private set; }

    public DateTime ClockInTime { get; private set; }
    public DateTime? ClockOutTime { get; private set; }

    public DateTime LastModified { get; set; } = DateTime.UtcNow;

    public TimeClockEntry() { }

    private TimeClockEntry(int companyId, int userId, DateTime clockInTime)
    {
        CompanyId = companyId;
        UserId = userId;
        ClockInTime = clockInTime;
    }

    public static TimeClockEntry Create(int companyId, int userId, DateTime clockInTime)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (userId <= 0) throw new ArgumentException("Invalid UserId");
        return new TimeClockEntry(companyId, userId, clockInTime);
    }

    public void ClockOut(DateTime clockOutTime)
    {
        ClockOutTime = clockOutTime;
    }

    public void SyncFrom(DateTime clockInTime, DateTime? clockOutTime)
    {
        ClockInTime = clockInTime;
        ClockOutTime = clockOutTime;
    }
}
