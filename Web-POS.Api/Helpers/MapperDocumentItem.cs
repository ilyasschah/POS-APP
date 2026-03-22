using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperDocumentItem
    {
        public static DocumentItemDto MapToDocumentItem (DocumentItem documentItem)
        {
            return new DocumentItemDto
            {
                Id = documentItem.Id,
                DocumentId = documentItem.DocumentId,
                DocumentNumber = documentItem.Document.Number,
                ProductId = documentItem.ProductId,
                ProductName = documentItem.Product?.Name,
                Quantity = documentItem.Quantity,
                Price = documentItem.Price,
                Discount = documentItem.Discount,
                DiscountType = documentItem.DiscountType,
                ProductCost = documentItem.ProductCost,
                PriceBeforeTaxAfterDiscount = documentItem.PriceBeforeTaxAfterDiscount,
                PriceAfterDiscount = documentItem.PriceAfterDiscount,
                Total = documentItem.Total,
                TotalAfterDocumentDiscount = documentItem.TotalAfterDocumentDiscount
                //DateCreated = documentItem.DateCreated,
                //DateUpdated = documentItem.DateUpdated
            };
        }
    }
}
