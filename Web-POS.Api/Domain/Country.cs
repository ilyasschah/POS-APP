using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// Global, read-only reference table shared by all companies. Seeded once
    /// (via SQL); not company-scoped and not editable through the API.
    /// </summary>
    [Table("Country")]
    public class Country
    {
        [Key]
        public int Id { get; set; }
        public string? Name { get; set; }
        public string? Code { get; set; }

        public Country() { }
    }
}
