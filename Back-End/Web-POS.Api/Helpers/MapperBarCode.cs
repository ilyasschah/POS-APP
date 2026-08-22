using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperBarcode
    {
        public static BarcodeDto MapToBarcodeDto(Barcode entity) 
        {
            return new BarcodeDto
            {
                Id = entity.Id,
                Value = entity.Value ?? string.Empty,
                ProductId = entity.ProductId,
                ProductName = entity.Product?.Name ?? "N/A"
            };
        }
    }
}