using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperDocument
    {
        public static DocumentDto MapToDocumentDto(Document entity)
        {
            return new DocumentDto
            {
                Id = entity.Id,
                Number = entity.Number,
                UserId = entity.UserId,
                UserName = entity.User?.Username ?? "N/A",
                CustomerId = entity.CustomerId,
                CustomerName = entity.Customer?.Name,
                DocumentTypeId = entity.DocumentTypeId,
                DocumentTypeName = entity.DocumentType?.Name ?? "N/A",
                WarehouseId = entity.WarehouseId,
                WarehouseName = entity.Warehouse?.Name ?? "N/A",
                Date = entity.Date,
                Total = entity.Total,
                PaidStatus = entity.PaidStatus,
                Note = entity.Note,
                DateCreated = entity.DateCreated
            };
        }
    }
}