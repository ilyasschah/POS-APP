using Api.Domain;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;

namespace Api.Services
{
    public class DocumentService
    {
        private readonly DocumentRepository _documentRepository;

        public DocumentService(DocumentRepository documentRepository)
        {
            _documentRepository = documentRepository;
        }

        public async Task<bool> CreateAsync(CreateDocumentRequest request, int companyId)
        {
            var document = Document.Create(
                request.Number,
                request.UserId,
                companyId,
                request.DocumentTypeId,
                request.WarehouseId,
                request.Total,
                request.CustomerId,
                request.OrderNumber,
                request.Date,
                request.StockDate,
                request.IsClockedOut ?? false,
                request.ReferenceDocumentNumber,
                request.InternalNote,
                request.Note,
                request.DueDate,
                request.Discount ?? 0,
                request.DiscountType ?? 0,
                request.PaidStatus ?? 0,
                request.DiscountApplyRule ?? false,
                request.ServiceType ?? 0
            );

            await _documentRepository.AddAsync(document);
            return true;
        }

        public async Task<bool> UpdateAsync(UpdateDocumentRequest request, int companyId)
        {
            if (request.Id <= 0)
                throw new ArgumentException("Document ID is required.");

            var document = await _documentRepository.GetByIdAsync(request.Id, companyId);
            if (document == null)
                throw new KeyNotFoundException($"Document with ID {request.Id} not found.");
             document.UpdateDetails(
                request.Number ?? document.Number,
                request.ReferenceDocumentNumber ?? document.ReferenceDocumentNumber,
                request.CustomerId ?? document.CustomerId,
                request.Total ?? document.Total,
                request.PaidStatus ?? document.PaidStatus,
                request.Date ?? document.Date,
                request.DueDate ?? document.DueDate,
                request.StockDate ?? document.StockDate,
                request.Discount ?? document.Discount,
                request.WarehouseId ?? document.WarehouseId,
                request.InternalNote ?? document.InternalNote,
                request.Note ?? document.Note,
                request.DiscountApplyRule ?? document.DiscountApplyRule
                

            );

            await _documentRepository.UpdateAsync(document);
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var document = await _documentRepository.GetByIdAsync(id, companyId);
            if (document == null)
            {
                throw new KeyNotFoundException($"Document with ID {id} not found.");
            }

            try
            {
                await _documentRepository.DeleteAsync(document);
                return true;
            }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException sqlEx && sqlEx.Number == 547)
            {
                throw new InvalidOperationException("This document has related records tied to it, so you cannot delete it.");
            }
        }
    }
}