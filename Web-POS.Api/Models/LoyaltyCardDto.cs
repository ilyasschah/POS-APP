// FILE: Products.Api.Models\LoyaltyCardDto.cs

namespace Api.Models;

public class LoyaltyCardDto
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public string CustomerName { get; set; }
    public string? CardNumber { get; set; }
    public decimal Points { get; set; }
    public DateTime LastModified { get; set; }
}

public class CreateLoyaltyCardRequest
{
    public required int CustomerId { get; set; }
    public string? CardNumber { get; set; }
}

public class UpdateLoyaltyCardRequest
{
    public required int Id { get; set; }
    public string? CardNumber { get; set; }
}

// ── Batch Sync ────────────────────────────────────────────────────────────────

// Single card payload sent by the tablet during a sync.
// CompanyId is NOT included — it comes from the [FromQuery] companyId on the endpoint,
// which is the authoritative tenant identifier for this request.
public class SyncLoyaltyCardDto
{
    // 0 or null means the card was created offline and has no server ID yet.
    public int? Id { get; set; }
    public required int CustomerId { get; set; }
    public string? CardNumber { get; set; }
    public decimal Points { get; set; }
    public DateTime LastModified { get; set; }
}

public class BatchSyncLoyaltyCardsRequest
{
    public required List<SyncLoyaltyCardDto> Cards { get; set; }
}

public class BatchSyncLoyaltyCardsResponse
{
    public int SyncedCount { get; set; }
    public int InsertedCount { get; set; }
    public int UpdatedCount { get; set; }
    public List<string> Errors { get; set; } = [];
}
