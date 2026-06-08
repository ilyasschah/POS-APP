namespace Api.Models;

public class ShiftDto
{
    public int Id { get; set; }
    public int CompanyId { get; set; }
    public int UserId { get; set; }
    public DateTime OpenedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public decimal StartingCash { get; set; }
    public decimal? ActualEndingCash { get; set; }
    public int Status { get; set; }
    public DateTime LastModified { get; set; }
}

public class SyncShiftDto
{
    /// <summary>0 or null means offline-created (no server ID yet).</summary>
    public int? ServerId { get; set; }
    public required string LocalId { get; set; }
    public int UserId { get; set; }
    public DateTime OpenedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public decimal StartingCash { get; set; }
    public decimal? ActualEndingCash { get; set; }
    public int Status { get; set; }
    public DateTime LastModified { get; set; }
}

public class BatchSyncShiftsRequest
{
    public required List<SyncShiftDto> Shifts { get; set; }
}

public class BatchSyncShiftsResponse
{
    public int SyncedCount { get; set; }
    public int InsertedCount { get; set; }
    public int UpdatedCount { get; set; }
    public List<SyncedShiftResult> Results { get; set; } = [];
    public List<string> Errors { get; set; } = [];
}

public class SyncedShiftResult
{
    public string LocalId { get; set; } = string.Empty;
    public int ServerId { get; set; }
}
