using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperProduct
    {
        public static ProductDto MapToProductDto(Product entity)
        {
            return new ProductDto
            {
                Id = entity.Id,
                ProductGroupId = entity.ProductGroupId,
                Name = entity.Name,
                Code = entity.Code,
                PLU = entity.PLU,
                MeasurementUnit = entity.MeasurementUnit,
                Price = entity.Price,
                IsTaxInclusivePrice = entity.IsTaxInclusivePrice,
                CurrencyId = entity.CurrencyId,
                IsPriceChangeAllowed = entity.IsPriceChangeAllowed,
                IsService = entity.IsService,
                IsUsingDefaultQuantity = entity.IsUsingDefaultQuantity,
                IsEnabled = entity.IsEnabled,
                Description = entity.Description,
                DateCreated = entity.DateCreated,
                DateUpdated = entity.DateUpdated,
                Cost = entity.Cost,
                Markup = entity.Markup,
                Image = entity.Image,
                Color = entity.Color,
                AgeRestriction = entity.AgeRestriction,
                LastPurchasePrice = entity.LastPurchasePrice,
                Rank = entity.Rank
            };
        }
    }
}
