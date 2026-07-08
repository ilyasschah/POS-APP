using Api.Domain;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Services
{
    public class PaymentService
    {
        private readonly PaymentRepository _repository;
        private readonly DocumentRepository _documentRepository; // Inject Document Repo!

        public PaymentService(PaymentRepository repository, DocumentRepository documentRepository)
        {
            _repository = repository;
            _documentRepository = documentRepository;
        }

        public async Task<PaymentDto> Create(CreatePaymentRequest req, int companyId)
        {
            // 1. Fetch the Document to get its Total
            var document = await _documentRepository.GetByIdAsync(req.DocumentId, companyId);
            if (document == null) throw new InvalidOperationException("Document not found.");

            // 2. Fetch all existing payments for this document
            var existingPayments = await _repository.GetByDocumentIdAsync(req.DocumentId, companyId);
            var currentPaymentsTotal = existingPayments.Sum(p => p.Amount);

            // 3. VALIDATION: Check if the new payment exceeds the document total
            var proposedTotal = currentPaymentsTotal + req.Amount;
            if (proposedTotal > document.Total)
            {
                var difference = proposedTotal - document.Total;
                throw new InvalidOperationException(
                    $"Invalid payment amount. Payments amount cannot exceed document total. " +
                    $"Document total: {document.Total:F2}. Proposed payments amount: {proposedTotal:F2}. " +
                    $"Difference to remove: {difference:F2}.");
            }

            var newPayment = Payment.Create(companyId, req.DocumentId, req.PaymentTypeId, req.Amount, req.UserId);

            await _repository.AddAsync(newPayment);

            var savedPayment = await _repository.GetByIdAsync(newPayment.Id, companyId);
            return MapperPayment.MapToPaymentDto(savedPayment!);
        }

        public async Task<PaymentDto> Update(UpdatePaymentRequest req, int companyId)
        {
            var paymentToUpdate = await _repository.GetByIdAsync(req.Id, companyId);
            if (paymentToUpdate == null) throw new InvalidOperationException("Payment not found.");

            var document = await _documentRepository.GetByIdAsync(paymentToUpdate.DocumentId, companyId);
            if (document == null) throw new InvalidOperationException("Document not found.");

            var existingPayments = await _repository.GetByDocumentIdAsync(paymentToUpdate.DocumentId, companyId);
            var otherPaymentsTotal = existingPayments.Where(p => p.Id != req.Id).Sum(p => p.Amount);

            // 3. VALIDATION: Check if the updated payment exceeds the document total
            var proposedTotal = otherPaymentsTotal + req.Amount;
            if (proposedTotal > document.Total)
            {
                var difference = proposedTotal - document.Total;
                throw new InvalidOperationException(
                    $"Invalid payment amount. Payments amount cannot exceed document total. " +
                    $"Document total: {document.Total:F2}. Proposed payments amount: {proposedTotal:F2}. " +
                    $"Difference to remove: {difference:F2}.");
            }

            paymentToUpdate.Update(req.Amount, req.Date);
            await _repository.UpdateAsync(paymentToUpdate);

            return MapperPayment.MapToPaymentDto(paymentToUpdate);
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var paymentToDelete = await _repository.GetByIdAsync(id, companyId);
            if (paymentToDelete == null) throw new InvalidOperationException("Payment not found.");

            if (paymentToDelete.ZReportId.HasValue)
                throw new InvalidOperationException("Cannot delete a payment that has already been reported on a Z-Report.");

            await _repository.DeleteAsync(paymentToDelete);
            return true;
        }
    }
}