namespace Api.Models
{
    public class PaymentDto
    {
        public int Id { get; set; }
        public int DocumentId { get; set; }
        public int PaymentTypeId { get; set; }
        public string PaymentTypeName { get; set; }
        public decimal Amount { get; set; }
        public DateTime? Date { get; set; }
        public int UserId { get; set; }
        public string UserName { get; set; }
        public int? ZReportId { get; set; }
        public DateTime DateCreated { get; set; }
    }

    public class CreatePaymentRequest
    {
        public required int DocumentId { get; set; }
        public required int PaymentTypeId { get; set; }
        public required decimal Amount { get; set; }
        public DateTime? Date { get; set; }
        public required int UserId { get; set; }
    }

    public class UpdatePaymentRequest
    {
        public required decimal Amount { get; set; }
        public DateTime? Date { get; set; }
    }
}