using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("StartingCash")]
    public class StartingCash
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }

        [Required]
        [ForeignKey(nameof(User))]
        public int UserId { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        public string? Description { get; set; }

        /// <summary>
        /// What kind of row this is: <b>0 = cash in</b>, <b>1 = cash out</b>,
        /// <b>2 = opening float</b>.
        ///
        /// 🚨 Kind 2 is displayed, never summed. Expected cash is
        /// <c>openingCash + cashPayments + cashIn - cashOut</c>, and
        /// <c>openingCash</c> already comes from the session's own
        /// <c>StartingCash</c> — so folding an opening-float row into either
        /// total counts the same money twice and every register reads over by
        /// its float. Every consumer here filters for <c>== 0</c> or
        /// <c>== 1</c> explicitly for exactly that reason
        /// (<c>PosSessionRepository.GetCashMovementTotalsAsync</c>,
        /// <c>ZReportService</c>): never sum by "not 1".
        /// </summary>
        public int StartingCashType { get; set; } = 0;

        public int? ZReportNumber { get; set; }

        [Required]
        public DateTime DateCreated { get; set; }

        /// <summary>
        /// The POS session this belongs to. Nullable — every existing write
        /// path leaves it null, so nothing that works today changes.
        /// </summary>
        public int? SessionId { get; set; }

        // Navigation
        public User? User { get; set; }

        public StartingCash() { }

        private StartingCash(int userId, decimal amount, string? description, int startingCashType, int? zReportNumber, DateTime dateCreated)
        {
            UserId = userId;
            Amount = amount;
            Description = description;
            StartingCashType = startingCashType;
            ZReportNumber = zReportNumber;
            DateCreated = dateCreated;
        }

        public static StartingCash Create(int userId, decimal amount, string? description, int startingCashType, int? zReportNumber, DateTime dateCreated)
            => new(userId, amount, description, startingCashType, zReportNumber, dateCreated);

        public void Update(int userId, decimal amount, string? description, int startingCashType, int? zReportNumber, DateTime dateCreated)
        {
            UserId = userId;
            Amount = amount;
            Description = description;
            StartingCashType = startingCashType;
            ZReportNumber = zReportNumber;
            DateCreated = dateCreated;
        }
    }
}
