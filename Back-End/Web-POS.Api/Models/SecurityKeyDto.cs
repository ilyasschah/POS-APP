namespace Api.Models
{
    public class SecurityKeyDto
    {
        public string? Name { get; set; }
        public int Level { get; set; }
    }

    public class UpdateSecurityKeyRequest
    {
        public required string Name { get; set; }

        public required int Level { get; set; }
    }
}