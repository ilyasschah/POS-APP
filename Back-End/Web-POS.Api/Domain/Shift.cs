using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

[Table("Shift")]
public class Shift : ISyncableEntity
{
    [Key]
    public int Id { get; private set; }

    public int CompanyId { get; private set; }
    public int UserId { get; private set; }

    public DateTime OpenedAt { get; private set; }
    public DateTime? ClosedAt { get; private set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal StartingCash { get; private set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal? ActualEndingCash { get; private set; }

    /// <summary>0 = Open, 1 = Closed</summary>
    public int Status { get; private set; }

    public DateTime LastModified { get; set; } = DateTime.UtcNow;

    public Shift() { }

    private Shift(int companyId, int userId, decimal startingCash)
    {
        CompanyId = companyId;
        UserId = userId;
        StartingCash = startingCash;
        OpenedAt = DateTime.UtcNow;
        Status = 0;
    }

    public static Shift Create(int companyId, int userId, decimal startingCash)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (userId <= 0) throw new ArgumentException("Invalid UserId");
        if (startingCash < 0) throw new ArgumentException("StartingCash cannot be negative");
        return new Shift(companyId, userId, startingCash);
    }

    public void Close(decimal actualEndingCash)
    {
        Status = 1;
        ClosedAt = DateTime.UtcNow;
        ActualEndingCash = actualEndingCash;
    }

    public void SyncFrom(DateTime openedAt, DateTime? closedAt, decimal startingCash, decimal? actualEndingCash, int status)
    {
        OpenedAt = openedAt;
        ClosedAt = closedAt;
        StartingCash = startingCash;
        ActualEndingCash = actualEndingCash;
        Status = status;
    }
}
