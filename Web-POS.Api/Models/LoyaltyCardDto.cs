// FILE: Products.Api.Models\LoyaltyCardDto.cs

namespace Api.Models;

public class LoyaltyCardDto
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public string CustomerName { get; set; }
    public string? CardNumber { get; set; }
}

public class CreateLoyaltyCardRequest
{
    public required int CustomerId { get; set; }
    public string? CardNumber { get; set; }
}

public class UpdateLoyaltyCardRequest
{
    public required int Id { get; set; }
    public string? CardNumber { get; set; }
}
