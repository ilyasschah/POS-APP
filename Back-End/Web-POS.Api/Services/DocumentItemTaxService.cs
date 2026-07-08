using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class DocumentItemTaxService
    {
        private readonly DocumentItemTaxRepository _repository;
        private readonly DocumentItemRepository _documentItemRepository;
        private readonly TaxRepository _taxRepository;

        public DocumentItemTaxService(
            DocumentItemTaxRepository repository,
            DocumentItemRepository documentItemRepository,
            TaxRepository taxRepository)
        {
            _repository = repository;
            _documentItemRepository = documentItemRepository;
            _taxRepository = taxRepository;
        }

        public async Task<DocumentItemTaxDto> Create(CreateDocumentItemTaxRequest req, int companyId)
        {
            var exists = await _repository.ExistsAsync(req.DocumentItemId, req.TaxId, companyId);
            if (exists)
                throw new InvalidOperationException("This tax is already applied to the document item.");

            var documentItem = await _documentItemRepository.GetByIdAsync(req.DocumentItemId, companyId);
            if (documentItem == null)
                throw new InvalidOperationException("Document item not found.");

            var tax = await _taxRepository.GetTaxByIdAsync(req.TaxId, companyId);
            if (tax == null)
                throw new InvalidOperationException("Tax not found.");

            decimal rate = Convert.ToDecimal(tax.Rate);
            decimal priceBeforeTax = Convert.ToDecimal(documentItem.PriceBeforeTax);
            decimal quantity = Convert.ToDecimal(documentItem.Quantity);

            decimal taxRateDecimal = rate / 100m;
            decimal taxPerItem = priceBeforeTax * taxRateDecimal;
            decimal totalTaxAmount = Math.Round(taxPerItem * quantity, 4);

            // 2. Create and Save
            var newDocumentItemTax = DocumentItemTax.Create(
                req.DocumentItemId,
                req.TaxId,
                totalTaxAmount,
                companyId
            );

            await _repository.AddAsync(newDocumentItemTax);

            // After adding the tax, recalculate the item's price and total
            await RecalculateItemAsync(req.DocumentItemId, companyId);

            return new DocumentItemTaxDto
            {
                DocumentItemId = newDocumentItemTax.DocumentItemId,
                TaxId = newDocumentItemTax.TaxId,
                TaxName = tax.Name,
                Amount = newDocumentItemTax.Amount
            };
        }

        public async Task<DocumentItemTaxDto> Update(UpdateDocumentItemTaxRequest req, int companyId)
        {
            var entityToUpdate = await _repository.GetByIdsAsync(req.DocumentItemId, req.TaxId, companyId);
            if (entityToUpdate == null)
                throw new InvalidOperationException("Document item tax not found.");

            var documentItem = await _documentItemRepository.GetByIdAsync(req.DocumentItemId, companyId);
            var tax = await _taxRepository.GetTaxByIdAsync(req.TaxId, companyId);

            if (documentItem != null && tax != null)
            {
                // 1. Calculate the exact math based on PriceBeforeTax
                decimal rate = Convert.ToDecimal(tax.Rate);
                decimal priceBeforeTax = Convert.ToDecimal(documentItem.PriceBeforeTax);
                decimal quantity = Convert.ToDecimal(documentItem.Quantity);

                decimal taxRateDecimal = rate / 100m;
                decimal taxPerItem = priceBeforeTax * taxRateDecimal;
                decimal totalTaxAmount = Math.Round(taxPerItem * quantity, 4);

                // 2. Update the existing entity (DO NOT CREATE NEW)
                entityToUpdate.UpdateAmount(totalTaxAmount);
                await _repository.UpdateAsync(entityToUpdate);
            }

            return new DocumentItemTaxDto
            {
                DocumentItemId = entityToUpdate.DocumentItemId,
                TaxId = entityToUpdate.TaxId,
                TaxName = tax?.Name ?? "N/A",
                Amount = entityToUpdate.Amount
            };
        }

        public async Task<bool> Delete(int documentItemId, int taxId, int companyId)
        {
            var entityToDelete = await _repository.GetByIdsAsync(documentItemId, taxId, companyId);

            if (entityToDelete == null)
                throw new InvalidOperationException("Document item tax not found.");

            await _repository.DeleteAsync(entityToDelete);

            // After removing the tax, recalculate the item's price and total
            await RecalculateItemAsync(documentItemId, companyId);

            return true;
        }

        // Recomputes DocumentItem.Price and .Total after any tax change.
        // Price = PriceBeforeTax × (1 + sumOfAllAppliedRates / 100)
        private async Task RecalculateItemAsync(int documentItemId, int companyId)
        {
            var item = await _documentItemRepository.GetByIdAsync(documentItemId, companyId);
            if (item == null) return;

            var appliedTaxes = await _repository.GetByDocumentItemIdAsync(documentItemId, companyId);
            decimal totalTaxRate = appliedTaxes
                .Where(t => t.Tax != null)
                .Sum(t => t.Tax!.Rate);

            decimal pbt = item.PriceBeforeTax;
            decimal price = pbt * (1 + totalTaxRate / 100m);

            decimal disc = item.Discount;
            int discType = item.DiscountType;

            decimal discountBase = discType == 0 ? pbt * (disc / 100m) : disc;
            decimal discountTaxed = discType == 0 ? price * (disc / 100m) : disc;
            decimal pbtd = pbt - discountBase;
            decimal pad = price - discountTaxed;
            decimal total = pad * item.Quantity;

            item.UpdateDetails(
                item.DocumentId, item.ProductId, item.Quantity, item.ExpectedQuantity,
                pbt, price, disc, discType, item.ProductCost,
                pbtd, pad, total, total, item.DiscountApplyRule);

            await _documentItemRepository.UpdateAsync(item);
        }
    }
}