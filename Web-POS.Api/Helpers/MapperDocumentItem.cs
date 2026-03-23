using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperDocumentItem
    {
        public static DocumentItemDto MapToDto(DocumentItem entity)
        {
            if (entity == null) return null;

            return new DocumentItemDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                DocumentId = entity.DocumentId,
                DocumentNumber = entity.Document?.Number,
                ProductId = entity.ProductId,
                ProductName = entity.Product?.Name,
                Quantity = entity.Quantity,
                ExpectedQuantity = entity.ExpectedQuantity,
                PriceBeforeTax = entity.PriceBeforeTax,
                Price = entity.Price,
                Discount = entity.Discount,
                DiscountType = entity.DiscountType,
                ProductCost = entity.ProductCost,
                PriceBeforeTaxAfterDiscount = entity.PriceBeforeTaxAfterDiscount,
                PriceAfterDiscount = entity.PriceAfterDiscount,
                Total = entity.Total,
                TotalAfterDocumentDiscount = entity.TotalAfterDocumentDiscount,
                DiscountApplyRule = entity.DiscountApplyRule
            };
        }
    }
}