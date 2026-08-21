using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class DocumentItemService
    {
        private readonly DocumentItemRepository _itemRepository;
        private readonly ProductRepository _productRepository;
        private readonly DocumentRepository _documentRepository;
        private readonly AppDbContext _db;

        public DocumentItemService(
            DocumentItemRepository itemRepository,
            ProductRepository productRepository,
            DocumentRepository documentRepository,
            AppDbContext db)
        {
            _itemRepository = itemRepository;
            _productRepository = productRepository;
            _documentRepository = documentRepository;
            _db = db;
        }

        public async Task<DocumentItemDto> CreateAsync(CreateDocumentItemRequest request, int companyId)
        {
            var product = await _productRepository.GetByIdAsync(request.ProductId, companyId);
            if (product == null) throw new UnauthorizedAccessException("Invalid Product.");

            var document = await _documentRepository.GetByIdAsync(request.DocumentId, companyId);
            if (document == null) throw new UnauthorizedAccessException("Invalid Document.");

            // DiscountType 0 = percentage, 1 = fixed amount
            decimal discountBase = request.DiscountType == 0
                ? request.PriceBeforeTax * (request.Discount / 100m)
                : request.Discount;

            decimal discountTaxed = request.DiscountType == 0
                ? request.Price * (request.Discount / 100m)
                : request.Discount;

            decimal pbtd = request.PriceBeforeTax - discountBase;
            decimal pad = request.Price - discountTaxed;
            decimal total = pad * request.Quantity;

            var entity = DocumentItem.Create(
                companyId, request.DocumentId, request.ProductId, request.Quantity, request.ExpectedQuantity,
                request.PriceBeforeTax, request.Price, request.Discount, request.DiscountType,
                request.ProductCost, pbtd, pad, total, total, request.DiscountApplyRule);

            await _itemRepository.AddAsync(entity);

            // Add stock for purchase documents — no IsService exclusion:
            // buying something always puts it in stock regardless of product type
            if (document.DocumentTypeId == DocumentTypeConstants.Purchase)
                await AdjustStockAsync(document.WarehouseId, request.ProductId, companyId, request.Quantity);

            // Stock return sends goods back to supplier → subtract from stock
            if (document.DocumentTypeId == DocumentTypeConstants.StockReturn)
                await AdjustStockAsync(document.WarehouseId, request.ProductId, companyId, -request.Quantity);

            // Loss and damage removes items from stock
            if (document.DocumentTypeId == DocumentTypeConstants.LossAndDamage)
                await AdjustStockAsync(document.WarehouseId, request.ProductId, companyId, -request.Quantity);

            return MapperDocumentItem.MapToDto(entity);
        }

        public async Task<bool> UpdateAsync(UpdateDocumentItemRequest request, int companyId)
        {
            var entity = await _itemRepository.GetByIdAsync(request.Id, companyId);
            if (entity == null) throw new KeyNotFoundException("Item not found.");

            decimal oldQuantity = entity.Quantity;

            int targetDocId = request.DocumentId ?? entity.DocumentId;
            if (request.DocumentId.HasValue && request.DocumentId.Value != entity.DocumentId)
            {
                var document = await _documentRepository.GetByIdAsync(targetDocId, companyId);
                if (document == null) throw new UnauthorizedAccessException("Invalid Document.");
            }

            int targetProdId = request.ProductId ?? entity.ProductId;
            if (request.ProductId.HasValue && request.ProductId.Value != entity.ProductId)
            {
                var product = await _productRepository.GetByIdAsync(targetProdId, companyId);
                if (product == null) throw new UnauthorizedAccessException("Invalid Product.");
            }

            decimal calcQuantity = request.Quantity ?? entity.Quantity;
            decimal calcPbt = request.PriceBeforeTax ?? entity.PriceBeforeTax;
            decimal calcPrice = request.Price ?? entity.Price;
            decimal calcDisc = request.Discount ?? entity.Discount;
            int calcDiscType = request.DiscountType ?? entity.DiscountType;

            // DiscountType 0 = percentage, 1 = fixed amount
            decimal discountBase = calcDiscType == 0 ? calcPbt * (calcDisc / 100m) : calcDisc;
            decimal discountTaxed = calcDiscType == 0 ? calcPrice * (calcDisc / 100m) : calcDisc;

            decimal pbtd = calcPbt - discountBase;
            decimal pad = calcPrice - discountTaxed;
            decimal total = pad * calcQuantity;

            entity.UpdateDetails(
                targetDocId, targetProdId, calcQuantity,
                request.ExpectedQuantity ?? entity.ExpectedQuantity, calcPbt, calcPrice,
                calcDisc, calcDiscType, request.ProductCost ?? entity.ProductCost,
                pbtd, pad, total, total, request.DiscountApplyRule ?? entity.DiscountApplyRule);

            var result = await _itemRepository.UpdateAsync(entity);

            // Delta stock adjustment for purchase and stock return documents
            decimal delta = calcQuantity - oldQuantity;
            if (delta != 0)
            {
                var doc = await _documentRepository.GetByIdAsync(targetDocId, companyId);
                if (doc != null && doc.DocumentTypeId == DocumentTypeConstants.Purchase)
                    await AdjustStockAsync(doc.WarehouseId, targetProdId, companyId, delta);
                else if (doc != null && doc.DocumentTypeId == DocumentTypeConstants.StockReturn)
                    await AdjustStockAsync(doc.WarehouseId, targetProdId, companyId, -delta);
                else if (doc != null && doc.DocumentTypeId == DocumentTypeConstants.LossAndDamage)
                    await AdjustStockAsync(doc.WarehouseId, targetProdId, companyId, -delta);
            }

            return result;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await _itemRepository.GetByIdAsync(id, companyId);
            if (entity == null) throw new KeyNotFoundException("Item not found.");

            // Reverse stock when a purchase or stock return item is removed
            var doc = await _documentRepository.GetByIdAsync(entity.DocumentId, companyId);
            if (doc != null && doc.DocumentTypeId == DocumentTypeConstants.Purchase)
                await AdjustStockAsync(doc.WarehouseId, entity.ProductId, companyId, -entity.Quantity);
            else if (doc != null && doc.DocumentTypeId == DocumentTypeConstants.StockReturn)
                await AdjustStockAsync(doc.WarehouseId, entity.ProductId, companyId, entity.Quantity);
            else if (doc != null && doc.DocumentTypeId == DocumentTypeConstants.LossAndDamage)
                await AdjustStockAsync(doc.WarehouseId, entity.ProductId, companyId, entity.Quantity);

            return await _itemRepository.DeleteAsync(entity);
        }

        /// <summary>
        /// Applies <paramref name="delta"/>, expressed in the PRODUCT's unit, to
        /// the warehouse's stock, which is held in that unit's category reference.
        /// </summary>
        /// <remarks>
        /// Every stock movement a document can make funnels through here, so this
        /// is the one place the conversion has to happen — receiving 500 g must
        /// add 0.500 kg, not 500.
        /// </remarks>
        private async Task AdjustStockAsync(int warehouseId, int productId, int companyId, decimal delta)
        {
            var uomId = await _db.Products
                .Where(p => p.Id == productId && p.CompanyId == companyId)
                .Select(p => (int?)p.UomId)
                .FirstOrDefaultAsync();

            var deltaInStockUnit = UnitOfMeasure.ToReference(delta, uomId);

            var stock = await _db.Stocks.FirstOrDefaultAsync(
                s => s.ProductId == productId && s.WarehouseId == warehouseId && s.CompanyId == companyId);

            if (stock != null)
            {
                stock.UpdateDetails(stock.Quantity + deltaInStockUnit, warehouseId, productId);
                _db.Stocks.Update(stock);
            }
            else
            {
                // Create a new stock record if none exists yet for this product/warehouse
                _db.Stocks.Add(Stock.Create(deltaInStockUnit, warehouseId, productId, companyId));
            }
            await _db.SaveChangesAsync();
        }
    }
}