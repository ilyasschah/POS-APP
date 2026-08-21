using System;

namespace Api.Models
{
    public class StartingCashDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int UserId { get; set; }
        public string? UserName { get; set; }
        public decimal Amount { get; set; }
        public string? Description { get; set; }
        public int StartingCashType { get; set; }
        public int? ZReportNumber { get; set; }
        public int? SessionId { get; set; }
        public DateTime DateCreated { get; set; }
    }

    public class CreateStartingCashRequest
    {
        public required int CompanyId { get; set; }
        public required int UserId { get; set; }
        public required decimal Amount { get; set; }
        public string? Description { get; set; }
        public int? StartingCashType { get; set; }   // default to 0 in service if null
        public int? ZReportNumber { get; set; }
        public DateTime? DateCreated { get; set; }   // default to UtcNow in service if null

        /// <summary>
        /// The session's CLIENT localId. A cash movement belongs to the session
        /// that was trading when it happened — binding it to a Z-report NUMBER
        /// (the legacy `ZReportNumber`) could not tell two registers apart,
        /// because that lookup was company-wide.
        /// </summary>
        public string? SessionLocalId { get; set; }
    }

    public class GetStartingCashByDateRangeRequest
    {
        public required int CompanyId { get; set; }
        public required DateTime StartDate { get; set; }
        public required DateTime EndDate { get; set; }
        public int? UserId { get; set; }
    }

    public class UpdateStartingCashRequest
    {
        public required int UserId { get; set; }
        public required decimal Amount { get; set; }
        public string? Description { get; set; }
        public required int StartingCashType { get; set; }
        public int? ZReportNumber { get; set; }
        public required DateTime DateCreated { get; set; }
    }
}
