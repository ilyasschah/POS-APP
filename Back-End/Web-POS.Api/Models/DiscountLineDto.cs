namespace Api.Models
{
    /// <summary>
    /// One applied discount carried from the client at checkout, persisted as a
    /// <see cref="Api.Domain.DiscountLine"/> linked to the created Document.
    /// ProductId is set for item-level discounts (manual item / promotion); null
    /// for whole-order discounts (manual cart / customer profile / loyalty points).
    /// </summary>
    public class DiscountLineDto
    {
        public int? ProductId { get; set; }
        public string Source { get; set; } = string.Empty;
        public int? SourceRefId { get; set; }
        public decimal Value { get; set; }
        public int ValueType { get; set; }
        public decimal Amount { get; set; }
        public int Sequence { get; set; }
        public string? Label { get; set; }
    }

    /// <summary>
    /// Read shape for pulling DiscountLine rows back to clients (multi-device
    /// consistency). Carries the server Id + DocumentId so a client can map each
    /// row to its local document (by Document.serverId) and de-duplicate.
    /// </summary>
    public class DiscountLinePullDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int DocumentId { get; set; }
        public int? ProductId { get; set; }
        public string Source { get; set; } = string.Empty;
        public int? SourceRefId { get; set; }
        public decimal Value { get; set; }
        public int ValueType { get; set; }
        public decimal Amount { get; set; }
        public int Sequence { get; set; }
        public string? Label { get; set; }
    }
}
