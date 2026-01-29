using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class DocumentService
    {
        public readonly DocumentRepository _repository;

        public DocumentService(DocumentRepository repository)
        {
            _repository = repository;
        }

        public async Task<Document> Create(CreateDocumentRequest req)
        {
            if (await _repository.ExistsAsync(req.Number))
            {
                throw new InvalidOperationException($"A document with the number '{req.Number}' already exists.");
            }

            var newDocument = Document.Create(
                req.Number,
                req.UserId,
                req.CompanyId,
                req.DocumentTypeId,
                req.WarehouseId,
                req.Total
            );

            newDocument.CustomerId = req.CustomerId;
            newDocument.OrderNumber = req.OrderNumber;
            newDocument.Date = req.Date ?? DateTime.UtcNow.Date;
            newDocument.StockDate = req.StockDate ?? DateTime.UtcNow;
            newDocument.IsClockedOut = req.IsClockedOut ?? false;
            newDocument.ReferenceDocumentNumber = req.ReferenceDocumentNumber;
            newDocument.InternalNote = req.InternalNote;
            newDocument.Note = req.Note;
            newDocument.DueDate = req.DueDate;
            newDocument.Discount = req.Discount ?? 0;
            newDocument.DiscountType = req.DiscountType ?? 0;
            newDocument.PaidStatus = req.PaidStatus ?? 0;
            newDocument.DiscountApplyRule = req.DiscountApplyRule ?? false;

            await _repository.AddAsync(newDocument);
            return newDocument;
        }

        public async Task<bool> Update(int id, UpdateDocumentRequest req)
        {
            var entityToUpdate = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToUpdate == null)
            {
                throw new InvalidOperationException($"A document with the ID '{id}' was not found.");
            }

            var existingByNumber = await _repository.GetByNumberAsync(req.Number);
            if (existingByNumber != null && existingByNumber.Id != id)
            {
                throw new InvalidOperationException($"Another document with the number '{req.Number}' already exists.");
            }

            entityToUpdate.Update(
                req.Number,
                req.CustomerId,
                req.Total,
                req.Note,
                req.PaidStatus
            );

            await _repository.UpdateAsync(entityToUpdate);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entityToDelete = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}