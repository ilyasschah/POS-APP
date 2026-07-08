using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperDocument
    {
        public static DocumentDto MapToDocumentDto(Document document)
        {
            return new DocumentDto
            {
                Id = document.Id,
                Number = document.Number,
                UserId = document.UserId,
                UserName = document.User?.Username ?? "N/A",
                CustomerId = document.CustomerId,
                CustomerName = document.Customer?.Name,
                CompanyId = document.CompanyId,
                CompanyName = document.Company?.Name ?? "N/A",
                DocumentTypeId = document.DocumentTypeId,
                DocumentTypeName = document.DocumentType?.Name ?? "N/A",
                WarehouseId = document.WarehouseId,
                WarehouseName = document.Warehouse?.Name ?? "N/A",
                Date = document.Date,
                Total = document.Total,
                PaidStatus = document.PaidStatus,
                OrderNumber = document.OrderNumber,
                Note = document.Note,
                DateCreated = document.DateCreated,
                DateUpdated = document.DateUpdated,
                ServiceType = document.ServiceType,
                Discount = document.Discount,
                DiscountType = document.DiscountType,
                DiscountApplyRule = document.DiscountApplyRule,
                ReferenceDocumentNumber = document.ReferenceDocumentNumber,
                DueDate = document.DueDate,
                StockDate = document.StockDate,
                InternalNote = document.InternalNote
            };
        }
    }
}