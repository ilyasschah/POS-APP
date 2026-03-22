using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ZReport")]
    public class ZReport
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int Number { get; set; }
        public int FromDocumentId { get; set; }
        public int ToDocumentId { get; set; }
        public DateTime DateCreated { get; set; } = DateTime.Now;

        private ZReport(int number, int fromdocumentid, int todocumentid, DateTime datecreation)
        {
            Number = number;
            FromDocumentId = fromdocumentid;
            ToDocumentId = todocumentid;
            DateCreated = datecreation;
        }
        public ZReport() { }
        public static ZReport Create(int number, int fromdocumentid, int todocumentid)
        {
            return new ZReport(number, fromdocumentid, todocumentid, DateTime.Now);
        }
    }
}
