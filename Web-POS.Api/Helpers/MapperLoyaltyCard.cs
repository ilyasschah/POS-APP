// FILE: Products.Api.Helpers\MapperLoyaltyCard.cs

using Api.Domain;
using Api.Models;

namespace Api.Helpers;

public static class MapperLoyaltyCard
{
    public static LoyaltyCardDto MapToLoyaltyCardDto(LoyaltyCard entity)
    {
        return new LoyaltyCardDto
        {
            Id = entity.Id,
            CustomerId = entity.CustomerId,
            CustomerName = entity.Customer?.Name ?? "N/A",
            CardNumber = entity.CardNumber
        };
    }
}
