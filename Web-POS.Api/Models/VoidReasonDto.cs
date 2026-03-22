using System;

namespace Api.Models
{
    public class VoidReasonDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int Rank { get; set; }
        public DateTime DateCreated { get; set; }
    }

    public class CreateVoidReasonRequest
    {
        public required string Name { get; set; }
        public required int Rank { get; set; }
    }

    public class UpdateVoidReasonRequest
    {
        public required string Name { get; set; }
        public required int Rank { get; set; }
    }
}