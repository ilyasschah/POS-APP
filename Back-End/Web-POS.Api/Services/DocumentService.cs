using Api.DataBase;
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
        private readonly DocumentItemService _itemService;
        private readonly AppDbContext _db;

        public DocumentService(
            DocumentRepository documentRepository,
            DocumentItemService itemService,
            AppDbContext db)
        {
            _documentRepository = documentRepository;
            _itemService = itemService;
            _db = db;
        }

        public async Task<DocumentDto> CreateAsync(CreateDocumentRequest request, int companyId)
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
            return new DocumentDto
            {
                Id = document.Id,
            };
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

        /// <summary>
        /// Deletes a document and gives back the stock its lines moved — exactly
        /// what deleting each line one by one gives back
        /// (<see cref="DocumentItemService.ReverseStockAsync"/>): the move its type's
        /// StockDirection made, the other way, and a count's variance. A POS
        /// document (with an OrderNumber) and a Proforma moved nothing through
        /// their lines and get nothing back. Without this the lines vanished with the document (they
        /// cascade) while their stock stayed, so stock on hand stopped adding up
        /// to the moves that are left.
        /// </summary>
        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            // 🚨 One unit, inside the execution strategy: the API runs with
            // EnableRetryOnFailure, which refuses a hand-rolled transaction, and a
            // document gone with its stock still out — or stock back with the
            // document still there — is exactly the mismatch this exists to stop.
            var strategy = _db.Database.CreateExecutionStrategy();
            var attempt = 0;
            try
            {
                await strategy.ExecuteAsync(async () =>
                {
                    // A replay starts from the database, never from what the
                    // failed attempt left tracked: the stock adjustment reads the
                    // TRACKED Stock row, so a stale one would be reversed twice.
                    if (attempt++ > 0) _db.ChangeTracker.Clear();

                    await using var tx = await _db.Database.BeginTransactionAsync();

                    var document = await _db.Documents
                        .FirstOrDefaultAsync(d => d.Id == id && d.CompanyId == companyId)
                        ?? throw new KeyNotFoundException($"Document with ID {id} not found.");

                    var items = await _db.DocumentItems
                        .Where(i => i.DocumentId == id)
                        .ToListAsync();
                    foreach (var item in items)
                        await _itemService.ReverseStockAsync(document, item, companyId);

                    // The lines, their taxes and the payments cascade with it.
                    _db.Documents.Remove(document);
                    await _db.SaveChangesAsync();
                    await tx.CommitAsync();
                });
                return true;
            }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException sqlEx && sqlEx.Number == 547)
            {
                throw new InvalidOperationException("This document has related records tied to it, so you cannot delete it.");
            }
        }
    }
}