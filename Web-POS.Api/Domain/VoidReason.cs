using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("VoidReason")]
    public class VoidReason
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; }
        public int Rank { get; set; }
        public DateTime DateCreated { get; set; }

        private VoidReason(string name, int rank)
        {
            Name = name;
            Rank = rank;
            DateCreated = DateTime.UtcNow;
        }

        public VoidReason() { }

        public static VoidReason Create(string name, int rank)
        {
            return new VoidReason(name, rank);
        }

        public void Update(string name, int rank)
        {
            Name = name;
            Rank = rank;
        }
    }
}