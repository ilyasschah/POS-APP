using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperBarcode
    {
        public static BarcodeDto MapBarCodes(Barcode barcodes)
        {
            return new BarcodeDto
            {
                Value = barcodes.Value,
                ProductName = barcodes.Product.Name
            };
        }
    }
}
