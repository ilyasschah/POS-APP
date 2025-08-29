using System.ComponentModel.DataAnnotations.Schema;

namespace Sales.Api.Domain
{
    [Table("StartingCash")]
    public class StartingCash
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public Decimal Amount { get; set; }
        public string? Description { get; set; }
        public int StartingCashType { get; set; }
        public int ZReportNumber { get; set; }
        public DateTime DateCreated { get; set; }
        [ForeignKey("UserId")]
        public virtual User User { get; set; }

        private StartingCash(int userid, Decimal amount, string? description, int startingcashtype, int zreportnumber)
        {
            UserId = userid;
            Amount = amount;
            Description = description;
            StartingCashType = startingcashtype;
            ZReportNumber = zreportnumber;
            DateCreated = DateTime.UtcNow;
        }
        public StartingCash() { }
        public static StartingCash Create(int userid, Decimal amount, string? description, int startingcashtype, int zreportnumber)
        {
            return new StartingCash(userid, amount, description, startingcashtype, zreportnumber);
        }

    }
}
