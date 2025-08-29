using Microsoft.Extensions.Hosting;
using Products.Api.Domain;
using Products.Api.Models;
using System.Drawing;

namespace Products.Api.Helpers
{
    public class MapperProduct
    {
        public static ProductDto MapToProductDetail(Product product)
        {
            return new ProductDto
            {
                Name = product.Name,
                Code = product.Code,
                PLU = product.PLU,
                MeasurementUnit = product.MeasurementUnit,
                Price = product.Price,
                IsTaxInclusivePrice = product.IsTaxInclusivePrice,
                IsPriceChangeAllowed = product.IsPriceChangeAllowed,
                IsService = product.IsService,
                IsUsingDefaultQuantity = product.IsUsingDefaultQuantity,
                IsEnabled = product.IsEnabled,
                Description = product.Description,
                Cost = product.Cost,
                Markup = product.Markup,
                Image = product.Image,
                Color = product.Color,
                AgeRestriction = product.AgeRestriction,
                LastPurchasePrice = product.LastPurchasePrice,
                Rank = product.Rank,
                ProductGroupName = product.ProductGroup.Name,
                ParentGroupName = product.ProductGroup.ParentGroup?.Name,
                CurrencyCode = product.Currency.Code,
                DateCreated = product.DateCreated,
                DateUpdated = product.DateUpdated,
            };
        }
        //public static CreateProductRequestDto MapToProduct(Product productDto)
        //{
        //    if (productDto == null)
        //        throw new ArgumentNullException(nameof(productDto));

        //    return new CreateProductRequestDto
        //    {
        //        Name = productDto.Name,
        //        Code = productDto.Code,
        //        Price = productDto.Price,
        //        //ProductGroup = new ProductGroupInfoDto
        //        //{
        //        //    Name = productDto.ProductGroup.Name,
        //        //    ParentGroupId = productDto.ProductGroup?.ParentGroupName,
        //        //    Color = productDto.ProductGroup?.Color,
        //        //},
        //        //Currency = new CurrencyDto
        //        //{ 
        //        //    Name = productDto.Currency.Name,
        //        //    Code = productDto.Currency.Code,
        //        //},
        //        IsService = productDto.IsService,
        //        IsEnabled = productDto.IsEnabled,
        //        Color = productDto.Color,
        //        Image = productDto.Image,
                
        //    };
        //}
    //    public static ProductGroupDto? MapToProductGroupDetail(ProductGroup productGroup)
    //    {
    //        if (productGroup == null)
    //        {
    //            return null;
    //        }
    //        return new ProductGroupDto
    //        {
    //            Name = productGroup.Name,
    //            Color = productGroup.Color,
    //            Image = productGroup.Image,
    //            Rank = productGroup.Rank,
    //            ParentGroupId = productGroup.ParentGroupId,
    //            ProductGroup = productGroup.ParentGroup == null ? null : new ProductGroupDto
    //            {
    //                Name = productGroup.ParentGroup.Name,
    //                Color = productGroup.ParentGroup.Color,
    //                Image = productGroup.ParentGroup.Image,
    //            },
    //            ChildGroups = productGroup.ChildGroups.Select(cg => new ProductGroupChildDto
    //                {
    //                    Id = cg.Id,
    //                    Name = cg.Name,
    //                    Color = cg.Color,
    //                    Image = cg.Image,
    //                }).ToList(),
    //        };
    //    }
    }
}
