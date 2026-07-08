namespace Api.Models;

public class TimeClockEntryDto
{
    public int Id { get; set; }
    public int CompanyId { get; set; }
    public int UserId { get; set; }
    public DateTime ClockInTime { get; set; }
    public DateTime? ClockOutTime { get; set; }
    public DateTime LastModified { get; set; }
}

public class SyncTimeClockEntryDto
{
    /// <summary>0 or null = offline-created entry with no server ID yet.</summary>
    public int? ServerId { get; set; }
    public required string LocalId { get; set; }
    public int UserId { get; set; }
    public DateTime ClockInTime { get; set; }
    public DateTime? ClockOutTime { get; set; }
    public DateTime LastModified { get; set; }
}

public class BatchSyncTimeClockRequest
{
    public required List<SyncTimeClockEntryDto> Entries { get; set; }
}

public class BatchSyncTimeClockResponse
{
    public int SyncedCount { get; set; }
    public int InsertedCount { get; set; }
    public int UpdatedCount { get; set; }
    public List<SyncedTimeClockResult> Results { get; set; } = [];
    public List<string> Errors { get; set; } = [];
}

public class SyncedTimeClockResult
{
    public string LocalId { get; set; } = string.Empty;
    public int ServerId { get; set; }
}
