namespace Api.Models
{
    public class UnpaidDocumentDto
    {
        public int      Id               { get; set; }
        public string   Number           { get; set; } = string.Empty;
        public string?  DocumentTypeName { get; set; }
        public DateTime Date             { get; set; }
        public string?  UserName         { get; set; }
        public decimal  Total            { get; set; }
        public decimal  Balance          { get; set; }
        public DateTime DateCreated      { get; set; }
        public string?  InternalNote     { get; set; }
        public string?  Note             { get; set; }
    }

    public class ApplyCreditPaymentRequest
    {
        public required int         CustomerId           { get; set; }
        public required int         PaymentTypeId        { get; set; }
        public required decimal     Amount               { get; set; }
        public required bool        IsAutomatic          { get; set; }
        public         List<int>    SelectedDocumentIds  { get; set; } = [];
    }
}
