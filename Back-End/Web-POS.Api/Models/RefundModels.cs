namespace Api.Models
{
    public class ProcessRefundRequest
    {
        public required string OriginalDocumentNumber { get; set; }
        public required int RefundPaymentTypeId { get; set; }
        public required int WarehouseId { get; set; }
        public List<RefundItemRequest> Items { get; set; } = new();

        /// Device-local refund number the client issued offline (220 series, e.g.
        /// "CAISSE1-220-000012"). When present, the refund keeps it verbatim
        /// instead of generating a server YY-220-NNNNNN number — so the offline
        /// refund's number survives sync unchanged.
        public string? ClientDocumentNumber { get; set; }

        /// Blind return: the refunding terminal never had the original receipt
        /// (sold on another POS while both were offline). There is no original
        /// Document to verify against — a manager authorised it at the till.
        /// When true, the handler skips the original-document lookup, takes item
        /// prices from <see cref="RefundItemRequest.Price"/>, and still issues a
        /// real 220 refund (reverse stock + negative payment).
        public bool IsBlind { get; set; }

        /// The manager (accessLevel 0) whose PIN authorised a blind return.
        /// Logged for audit. Required by the client when IsBlind is true.
        public int? ApprovedByUserId { get; set; }

        /// <summary>
        /// The POS session the money came OUT of — the client's session localId,
        /// same key a checkout sends.
        ///
        /// 🚨 A refund had no session field at all, so every refund Document and
        /// its negative Payment landed with `SessionId = NULL`. The closing
        /// count reads payments `WHERE SessionId = @id`, so the refunded cash
        /// was never deducted: a session that refunded 44.60 still expected the
        /// full takings, and the drawer came up 44.60 "short" at close through
        /// nobody's fault. The client had always stamped its LOCAL rows — it
        /// simply never told us. Reported 2026-08-29.
        ///
        /// Null is tolerated (a pre-session client, or a refund taken with the
        /// session guard off): the refund is banked unattached rather than
        /// refused, exactly as <c>PosSessionService.AttachSaleAsync</c> does.
        /// </summary>
        public string? SessionLocalId { get; set; }
    }

    public class RefundItemRequest
    {
        public required int ProductId { get; set; }
        public required decimal Quantity { get; set; }

        /// Unit price to refund. Only used for blind returns (no original line to
        /// copy from); the client sends the product's current selling price.
        /// Ignored on a verified refund — the original receipt's price wins.
        public decimal? Price { get; set; }
    }

    public class ProcessRefundResponse
    {
        public string RefundDocumentNumber { get; set; } = "";
        public decimal TotalRefunded { get; set; }
    }
}
