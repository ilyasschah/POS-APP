// FILE: Sales.Api.Helpers\MapperLoyaltyCard.cs

using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers;

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
