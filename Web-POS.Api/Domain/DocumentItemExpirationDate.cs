using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Keyless]
    [Table("DocumentItemExpirationDate")]
    public class DocumentItemExpirationDate
    {
        public int DocumentItemId { get; set; }
        public DateTime ExpirationDate { get; set; }
        [ForeignKey(nameof(DocumentItemId))]
        public virtual DocumentItem DocumentItem { get; set; }
        private DocumentItemExpirationDate(int documentitemid, DateTime expirationdate)
        {
            DocumentItemId = documentitemid;
            ExpirationDate = expirationdate;
        }
        public DocumentItemExpirationDate() {}
        public static DocumentItemExpirationDate Create(
            int documentitemid,
            DateTime expirationdate)
        {
            return new DocumentItemExpirationDate(
                documentitemid,
                expirationdate);
        }
        public void UpdateExpirationDate(DateTime expirationdate)
        {
            ExpirationDate = expirationdate;
        }
        
    }
}
