using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperBarcode_ProductName
    {
        public static BarcodeDto MapBarCodes(Barcode barcodes)
        {
            return new BarcodeDto
            {
                Id = barcodes.Id,
                Value = barcodes.Value,
                ProductId = barcodes.ProductId,
                ProductName = barcodes.Product.Name,
                CompanyId = barcodes.CompanyId,
                CompanyName = barcodes.Company.Name
            };
        }
    }
}
