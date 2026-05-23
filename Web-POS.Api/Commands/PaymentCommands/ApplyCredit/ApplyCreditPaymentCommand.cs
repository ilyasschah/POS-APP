using Api.DataBase;
using Api.Domain;
using Api.Models;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.PaymentCommands.ApplyCredit
{
    public class ApplyCreditPaymentCommand : IRequest<bool>
    {
        public ApplyCreditPaymentRequest Request   { get; }
        public int                       CompanyId { get; }
        public int                       UserId    { get; }

        public ApplyCreditPaymentCommand(
            ApplyCreditPaymentRequest request, int companyId, int userId)
        {
            Request   = request;
            CompanyId = companyId;
            UserId    = userId;
        }

        public class Handler : IRequestHandler<ApplyCreditPaymentCommand, bool>
        {
            private readonly AppDbContext _db;

            public Handler(AppDbContext db) => _db = db;

            public async Task<bool> Handle(
                ApplyCreditPaymentCommand command, CancellationToken cancellationToken)
            {
                var strategy = _db.Database.CreateExecutionStrategy();

                return await strategy.ExecuteAsync(async () =>
                {
                    using var tx = await _db.Database.BeginTransactionAsync(cancellationToken);
                    try
                    {
                        var req = command.Request;

                        // Resolve target documents (oldest first for waterfall)
                        IQueryable<Domain.Document> docsQuery = _db.Documents
                            .Where(d => d.CompanyId  == command.CompanyId
                                     && d.CustomerId == req.CustomerId
                                     && d.PaidStatus != 1)
                            .OrderBy(d => d.Date);

                        if (!req.IsAutomatic && req.SelectedDocumentIds.Count > 0)
                            docsQuery = docsQuery
                                .Where(d => req.SelectedDocumentIds.Contains(d.Id));

                        var docs = await docsQuery.ToListAsync(cancellationToken);

                        // Batch-load all relevant payment totals
                        var docIds = docs.Select(d => d.Id).ToList();
                        var paidByDoc = await _db.Payments
                            .Where(p => docIds.Contains(p.DocumentId)
                                     && p.CompanyId == command.CompanyId)
                            .GroupBy(p => p.DocumentId)
                            .Select(g => new { DocumentId = g.Key, Paid = g.Sum(p => p.Amount) })
                            .ToDictionaryAsync(x => x.DocumentId, x => x.Paid, cancellationToken);

                        decimal remaining = req.Amount;

                        foreach (var doc in docs)
                        {
                            if (remaining <= 0m) break;

                            var alreadyPaid = paidByDoc.GetValueOrDefault(doc.Id, 0m);
                            var docBalance  = doc.Total - alreadyPaid;
                            if (docBalance <= 0m) continue;

                            var apply = Math.Min(remaining, docBalance);

                            _db.Payments.Add(Payment.Create(
                                companyId:     command.CompanyId,
                                documentId:    doc.Id,
                                paymentTypeId: req.PaymentTypeId,
                                amount:        apply,
                                userId:        command.UserId));

                            // Update document paid status
                            var newBalance = docBalance - apply;
                            var newStatus  = newBalance <= 0m ? 1 : 2; // 1=Paid, 2=Partial

                            doc.UpdateDetails(
                                number:                  doc.Number,
                                referenceDocumentNumber: doc.ReferenceDocumentNumber,
                                customerId:              doc.CustomerId,
                                total:                   doc.Total,
                                paidStatus:              newStatus,
                                date:                    doc.Date,
                                dueDate:                 doc.DueDate,
                                stockDate:               doc.StockDate,
                                discount:                doc.Discount,
                                warehouseId:             doc.WarehouseId,
                                internalNote:            doc.InternalNote,
                                note:                    doc.Note,
                                discountApplyRule:       doc.DiscountApplyRule);

                            remaining -= apply;
                        }

                        await _db.SaveChangesAsync(cancellationToken);
                        await tx.CommitAsync(cancellationToken);
                        return true;
                    }
                    catch
                    {
                        await tx.RollbackAsync(cancellationToken);
                        throw;
                    }
                });
            }
        }

        public class Validator : AbstractValidator<ApplyCreditPaymentCommand>
        {
            public Validator()
            {
                RuleFor(c => c.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");
                RuleFor(c => c.UserId)
                    .GreaterThan(0).WithMessage("User ID must be valid.");
                RuleFor(c => c.Request.CustomerId)
                    .GreaterThan(0).WithMessage("Customer ID must be valid.");
                RuleFor(c => c.Request.PaymentTypeId)
                    .GreaterThan(0).WithMessage("Payment type must be selected.");
                RuleFor(c => c.Request.Amount)
                    .GreaterThan(0).WithMessage("Amount must be greater than zero.");
            }
        }
    }
}
