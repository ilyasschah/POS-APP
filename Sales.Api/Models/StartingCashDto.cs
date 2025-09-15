using System;

namespace Sales.Api.Models
{
    public class StartingCashDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public decimal Amount { get; set; }
        public string? Description { get; set; }
        public int StartingCashType { get; set; }
        public int? ZReportNumber { get; set; }
        public DateTime DateCreated { get; set; }
    }

    public class CreateStartingCashRequest
    {
        public required int UserId { get; set; }
        public required decimal Amount { get; set; }
        public string? Description { get; set; }
        public int? StartingCashType { get; set; }   // default to 0 in service if null
        public int? ZReportNumber { get; set; }
        public DateTime? DateCreated { get; set; }   // default to UtcNow in service if null
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
