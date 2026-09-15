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
        // DocumentType.StockDirection values, as seeded by GlobalDefaultsSeeder.
        private const int StockDirectionIn = 1;
        private const int StockDirectionOut = 2;

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

            // The document type decides which way the line's goods go. No IsService
            // exclusion: a line on a stock document moves what it says whatever the
            // product type — buying something always puts it in stock.
            var moved = await StockSignAsync(document)
                        * Moved(document.DocumentTypeId, request.Quantity, request.ExpectedQuantity);
            if (moved != 0)
                await AdjustStockAsync(document.WarehouseId, request.ProductId, companyId, moved);

            return MapperDocumentItem.MapToDto(entity);
        }

        public async Task<bool> UpdateAsync(UpdateDocumentItemRequest request, int companyId)
        {
            var entity = await _itemRepository.GetByIdAsync(request.Id, companyId);
            if (entity == null) throw new KeyNotFoundException("Item not found.");

            decimal oldQuantity = entity.Quantity;
            decimal oldExpected = entity.ExpectedQuantity;

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
            decimal calcExpected = request.ExpectedQuantity ?? entity.ExpectedQuantity;
            decimal calcPbt = request.PriceBeforeTax ?? entity.PriceBeforeTax;
            decimal calcPrice = request.Price ?? entity.Price;
            decimal calcDisc = request.Discount ?? entity.Discount;
            int calcDiscType = request.DiscountType ?? entity.DiscountType;

            // A percentage never takes from a fixed tax — Rate × quantity whatever
            // the discount. The editor's price carries the line's fixed taxes, so
            // they are left out of what the % is taken from, exactly as
            // DocumentItemTaxService.RecalculateItemAsync and the terminal do.
            // Summed in memory: SQLite cannot SUM a decimal column.
            decimal fixedPerUnit = (await _db.DocumentItemTaxes
                    .Where(t => t.DocumentItemId == entity.Id && t.CompanyId == companyId && t.Tax!.IsFixed)
                    .Select(t => t.Tax!.Rate)
                    .ToListAsync())
                .Sum();

            // DiscountType 0 = percentage, 1 = fixed amount
            decimal discountBase = calcDiscType == 0 ? calcPbt * (calcDisc / 100m) : calcDisc;
            decimal discountTaxed = calcDiscType == 0
                ? Math.Max(0m, calcPrice - fixedPerUnit) * (calcDisc / 100m)
                : calcDisc;

            decimal pbtd = calcPbt - discountBase;
            decimal pad = calcPrice - discountTaxed;
            decimal total = pad * calcQuantity;

            entity.UpdateDetails(
                targetDocId, targetProdId, calcQuantity,
                calcExpected, calcPbt, calcPrice,
                calcDisc, calcDiscType, request.ProductCost ?? entity.ProductCost,
                pbtd, pad, total, total, request.DiscountApplyRule ?? entity.DiscountApplyRule);

            var result = await _itemRepository.UpdateAsync(entity);

            // Delta logic: only what the line moves now minus what it moved before,
            // so an edit never applies the whole line a second time.
            if (calcQuantity != oldQuantity || calcExpected != oldExpected)
            {
                var doc = await _documentRepository.GetByIdAsync(targetDocId, companyId);
                if (doc != null)
                {
                    var delta = await StockSignAsync(doc)
                                * (Moved(doc.DocumentTypeId, calcQuantity, calcExpected)
                                   - Moved(doc.DocumentTypeId, oldQuantity, oldExpected));
                    if (delta != 0)
                        await AdjustStockAsync(doc.WarehouseId, targetProdId, companyId, delta);
                }
            }

            return result;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await _itemRepository.GetByIdAsync(id, companyId);
            if (entity == null) throw new KeyNotFoundException("Item not found.");

            var doc = await _documentRepository.GetByIdAsync(entity.DocumentId, companyId);
            if (doc != null) await ReverseStockAsync(doc, entity, companyId);

            return await _itemRepository.DeleteAsync(entity);
        }

        /// <summary>
        /// Gives back the stock one line moved — what removing it must undo: the
        /// same move, the other way. A line that moved nothing (a POS document's,
        /// a Proforma's, a count that agreed) gives nothing back.
        /// </summary>
        /// <remarks>
        /// Deleting one line and deleting a whole document
        /// (<see cref="DocumentService.DeleteAsync"/>) both come through here,
        /// which is what keeps the two from ever disagreeing.
        /// </remarks>
        public async Task ReverseStockAsync(Document doc, DocumentItem item, int companyId)
        {
            var moved = await StockSignAsync(doc)
                        * Moved(doc.DocumentTypeId, item.Quantity, item.ExpectedQuantity);
            if (moved != 0)
                await AdjustStockAsync(doc.WarehouseId, item.ProductId, companyId, -moved);
        }

        /// <summary>
        /// Which way a line of <paramref name="doc"/> moves goods: +1 into its
        /// warehouse, −1 out of it, 0 not at all. Read from the document type's
        /// <see cref="DocumentType.StockDirection"/> (1 in, 2 out, 0 none) rather
        /// than a list of type ids, so every type the table defines is honoured.
        /// </summary>
        /// <remarks>
        /// 🚨 A POS document — one carrying an OrderNumber — is always 0. Its stock
        /// is moved by the flow that wrote it (checkout, refund, void), never
        /// through its lines here: moving it again would take a sale out twice,
        /// and deleting a voided sale would restock what the void already had.
        /// </remarks>
        private async Task<decimal> StockSignAsync(Document doc)
        {
            if (!string.IsNullOrEmpty(doc.OrderNumber)) return 0m;

            var direction = await _db.DocumentTypes
                .Where(t => t.Id == doc.DocumentTypeId)
                .Select(t => t.StockDirection)
                .FirstOrDefaultAsync();

            return direction switch
            {
                StockDirectionIn => 1m,
                StockDirectionOut => -1m,
                _ => 0m,
            };
        }

        /// <summary>
        /// How much of a line moves, in the product's unit, before its sign: its
        /// quantity — or, on an inventory count, its variance (counted − expected).
        /// A count corrects stock to what was found; adding everything counted
        /// would double the shelf.
        /// </summary>
        /// <remarks>
        /// A line's sign is not a direction — the type's StockDirection is. A
        /// refund rung up on a till records its lines negative, like the money it
        /// gives back, and still brought the goods back in. Only a count's
        /// variance is signed. The terminal's Stock Moves reads lines the same way.
        /// </remarks>
        private static decimal Moved(int documentTypeId, decimal quantity, decimal expectedQuantity) =>
            documentTypeId == DocumentTypeConstants.InventoryCount
                ? quantity - expectedQuantity
                : Math.Abs(quantity);

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
            var unit = await _db.Products
                .Where(p => p.Id == productId && p.CompanyId == companyId)
                .Select(p => new { p.UomId, p.PackSize })
                .FirstOrDefaultAsync();

            var deltaInStockUnit = UnitOfMeasure.ToReference(delta, unit?.UomId, unit?.PackSize);

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
