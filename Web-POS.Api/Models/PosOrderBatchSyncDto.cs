namespace Api.Models
{
    /// <summary>
    /// Request body for POST /PosOrder/BatchSync.
    /// Each item carries the order header, its line items, and a client-generated
    /// LocalId (UUID). LocalId is never persisted server-side — it's echoed back
    /// so the Flutter sync engine can match server IDs to local Drift rows.
    /// </summary>
    public class BatchSyncPosOrdersRequest
    {
        public required List<BatchSyncOrderItem> Orders { get; set; }
    }

    public class BatchSyncOrderItem
    {
        public required string LocalId { get; set; }
        public required CreatePosOrderRequest Order { get; set; }
        public List<BulkAddPosOrderItemRequest> Items { get; set; } = new();
        public decimal OrderTotal { get; set; }
    }

    public class BatchSyncPosOrdersResponse
    {
        public List<BatchSyncResult> Results { get; set; } = new();
    }

    public class BatchSyncResult
    {
        public string LocalId { get; set; } = string.Empty;
        public int? ServerId { get; set; }
        public bool Success { get; set; }
        public string? Error { get; set; }
        public List<string> Warnings { get; set; } = new();
    }
}
