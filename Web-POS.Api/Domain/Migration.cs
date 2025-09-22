using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Migration")]
    public class Migration
    {
        [Key]
        public int Id { get; set; }

        [Required, MaxLength(100)]
        public string Version { get; set; } = default!;

        public string? Description { get; set; }

        [Required, MaxLength(255)]
        public string FileName { get; set; } = default!;

        [MaxLength(100)]
        public string? Module { get; set; }

        public DateTime? Date { get; set; }

        public Migration() { }

        private Migration(string version, string? description, string fileName, string? module, DateTime? date)
        {
            Version = version;
            Description = description;
            FileName = fileName;
            Module = module;
            Date = date;
        }

        public static Migration Create(string version, string? description, string fileName, string? module, DateTime? date)
            => new(version, description, fileName, module, date);

        public void Update(string version, string? description, string fileName, string? module, DateTime? date)
        {
            Version = version;
            Description = description;
            FileName = fileName;
            Module = module;
            Date = date;
        }
    }
}
