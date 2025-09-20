using System;

namespace Products.Api.Models
{
    public class MigrationDto
    {
        public int Id { get; set; }
        public string Version { get; set; } = default!;
        public string? Description { get; set; }
        public string FileName { get; set; } = default!;
        public string? Module { get; set; }
        public DateTime? Date { get; set; }
    }

    public class CreateMigrationRequest
    {
        public required string Version { get; set; }
        public string? Description { get; set; }
        public required string FileName { get; set; }
        public string? Module { get; set; }
        public DateTime? Date { get; set; }
    }

    public class UpdateMigrationRequest
    {
        public required string Version { get; set; }
        public string? Description { get; set; }
        public required string FileName { get; set; }
        public string? Module { get; set; }
        public DateTime? Date { get; set; }
    }
}
