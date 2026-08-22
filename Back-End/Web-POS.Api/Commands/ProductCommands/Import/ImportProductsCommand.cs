using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.ProductCommands.Import
{
    public class ImportProductsCommand : IRequest<ImportProductsResult>
    {
        public ImportProductsRequest Request { get; }
        public ImportProductsCommand(ImportProductsRequest request) => Request = request;
    }

    public class ImportProductsCommandHandler
        : IRequestHandler<ImportProductsCommand, ImportProductsResult>
    {
        private readonly AppDbContext _db;
        public ImportProductsCommandHandler(AppDbContext db) => _db = db;

        public async Task<ImportProductsResult> Handle(
            ImportProductsCommand command,
            CancellationToken ct)
        {
            var req = command.Request;
            var result = new ImportProductsResult();
            var companyId = req.CompanyId;

            // Pre-load lookup tables once
            var groupsByName = await _db.ProductGroups
                .Where(g => g.CompanyId == companyId)
                .ToDictionaryAsync(g => g.Name.ToLower(), ct);

            var productsByName = await _db.Products
                .Where(p => p.CompanyId == companyId)
                .ToDictionaryAsync(p => p.Name.ToLower(), ct);

            var taxesByRate = await _db.Taxes
                .Where(t => t.CompanyId == companyId)
                .GroupBy(t => t.Rate)
                .Select(g => g.First())
                .ToDictionaryAsync(t => t.Rate, ct);

            var existingBarcodes = (await _db.Barcodes
                .Where(b => b.CompanyId == companyId)
                .Select(b => b.Value)
                .ToListAsync(ct))
                .ToHashSet();

            var existingPtSet = (await _db.ProductsTaxes
                .Where(pt => pt.CompanyId == companyId)
                .Select(pt => new { pt.ProductId, pt.TaxId })
                .ToListAsync(ct))
                .Select(x => (x.ProductId, x.TaxId))
                .ToHashSet();

            var scByProduct = await _db.StockControls
                .Where(sc => sc.CompanyId == companyId)
                .ToDictionaryAsync(sc => sc.ProductId, ct);

            var suppliersByName = await _db.Customers
                .Where(c => c.CompanyId == companyId && c.IsSupplier && c.Name != null)
                .ToDictionaryAsync(c => c.Name!.ToLower(), ct);

            var firstWarehouse = await _db.Warehouses
                .Where(w => w.CompanyId == companyId)
                .OrderBy(w => w.Id)
                .FirstOrDefaultAsync(ct);

            var stockByProduct = firstWarehouse != null
                ? await _db.Stocks
                    .Where(s => s.CompanyId == companyId && s.WarehouseId == firstWarehouse.Id)
                    .ToDictionaryAsync(s => s.ProductId, ct)
                : [];

            // Track all successfully processed products for document creation
            var processedItems = new List<(Product product, decimal? quantity, decimal? taxRate, bool? isTaxInclusive)>();

            foreach (var row in req.Rows)
            {
                if (string.IsNullOrWhiteSpace(row.Name)) continue;

                try
                {
                    // 1. Find or create product group
                    int? groupId = null;
                    if (!string.IsNullOrWhiteSpace(row.ProductGroupName))
                    {
                        var gKey = row.ProductGroupName.Trim().ToLower();
                        if (!groupsByName.TryGetValue(gKey, out var grp))
                        {
                            grp = ProductGroup.Create(
                                name: row.ProductGroupName.Trim(),
                                parentGroupId: null,
                                color: "Transparent",
                                image: null,
                                rank: 0,
                                companyId: companyId);
                            _db.ProductGroups.Add(grp);
                            await _db.SaveChangesAsync(ct);
                            groupsByName[gKey] = grp;
                        }
                        groupId = grp.Id;
                    }

                    // 2. Find or create/merge product
                    var pKey = row.Name.Trim().ToLower();
                    Product product;
                    if (productsByName.TryGetValue(pKey, out var existing))
                    {
                        // Duplicate found — skip takes precedence; if not merging, skip
                        if (req.SkipDuplicates || !req.MergeDuplicates)
                        {
                            result.Skipped++;
                            continue;
                        }

                        existing.Update(
                            productGroupId:        groupId ?? existing.ProductGroupId,
                            name:                  existing.Name,
                            code:                  row.Code ?? existing.Code,
                            plu:                   existing.PLU,
                            measurementUnit:       row.MeasurementUnit ?? existing.MeasurementUnit,
                            price:                 row.Price ?? existing.Price,
                            isTaxInclusivePrice:   row.IsTaxInclusivePrice ?? existing.IsTaxInclusivePrice,
                            currencyId:            existing.CurrencyId,
                            isPriceChangeAllowed:  row.IsPriceChangeAllowed ?? existing.IsPriceChangeAllowed,
                            isService:             row.IsService ?? existing.IsService,
                            isUsingDefaultQuantity:row.IsUsingDefaultQuantity ?? existing.IsUsingDefaultQuantity,
                            isEnabled:             row.IsEnabled ?? existing.IsEnabled,
                            description:           row.Description ?? existing.Description,
                            dateUpdated:           DateTime.UtcNow,
                            cost:                  row.Cost ?? existing.Cost,
                            markup:                row.Markup ?? existing.Markup,
                            image:                 existing.Image,
                            color:                 existing.Color,
                            ageRestriction:        existing.AgeRestriction,
                            lastPurchasePrice:     existing.LastPurchasePrice,
                            rank:                  existing.Rank,
                            // A spreadsheet has no UoM id column, so the unit is
                            // derived from the text the row carries. A row that
                            // names no unit must leave the product's unit alone —
                            // re-deriving it would file every re-import under pieces.
                            uomId:                 row.MeasurementUnit != null
                                                       ? UnitOfMeasure.FromLegacyText(row.MeasurementUnit)
                                                       : existing.UomId,
                            isToWeigh:             row.IsToWeigh || existing.IsToWeigh);
                        product = existing;
                        result.Updated++;
                    }
                    else
                    {
                        product = Product.Create(
                            productGroupId:        groupId,
                            name:                  row.Name.Trim(),
                            code:                  row.Code,
                            plu:                   null,
                            measurementUnit:       row.MeasurementUnit,
                            price:                 row.Price ?? 0m,
                            isTaxInclusivePrice:   row.IsTaxInclusivePrice ?? true,
                            currencyId:            null,
                            isPriceChangeAllowed:  row.IsPriceChangeAllowed ?? false,
                            isService:             row.IsService ?? false,
                            isUsingDefaultQuantity:row.IsUsingDefaultQuantity ?? true,
                            isEnabled:             row.IsEnabled ?? true,
                            description:           row.Description,
                            dateCreated:           DateTime.UtcNow,
                            dateUpdated:           DateTime.UtcNow,
                            cost:                  row.Cost ?? 0m,
                            markup:                row.Markup,
                            image:                 null,
                            color:                 "Transparent",
                            ageRestriction:        null,
                            lastPurchasePrice:     null,
                            rank:                  0,
                            uomId:                 UnitOfMeasure.FromLegacyText(row.MeasurementUnit),
                            isToWeigh:             row.IsToWeigh);
                        product.CompanyId = companyId;
                        _db.Products.Add(product);
                        await _db.SaveChangesAsync(ct);
                        productsByName[pKey] = product;
                        result.Created++;
                    }

                    // 3. Tax
                    if (row.TaxRate.HasValue &&
                        taxesByRate.TryGetValue(row.TaxRate.Value, out var tax) &&
                        !existingPtSet.Contains((product.Id, tax.Id)))
                    {
                        _db.ProductsTaxes.Add(ProductTax.Create(product.Id, tax.Id, companyId));
                        existingPtSet.Add((product.Id, tax.Id));
                    }

                    // 4. Barcode
                    if (!string.IsNullOrWhiteSpace(row.Barcode) &&
                        !existingBarcodes.Contains(row.Barcode))
                    {
                        _db.Barcodes.Add(Barcode.Create(row.Barcode, product.Id, companyId));
                        existingBarcodes.Add(row.Barcode);
                    }

                    // 5. Stock control
                    int? supplierId = null;
                    if (!string.IsNullOrWhiteSpace(row.SupplierName) &&
                        suppliersByName.TryGetValue(row.SupplierName.Trim().ToLower(), out var supplier))
                        supplierId = supplier.Id;

                    if (supplierId.HasValue || row.ReorderPoint.HasValue ||
                        row.PreferredQuantity.HasValue || row.IsLowStockWarningEnabled.HasValue ||
                        row.LowStockWarningQuantity.HasValue)
                    {
                        if (!scByProduct.TryGetValue(product.Id, out var sc))
                        {
                            sc = StockControl.Create(product.Id, companyId);
                            _db.StockControls.Add(sc);
                            scByProduct[product.Id] = sc;
                        }
                        sc.Update(supplierId, row.ReorderPoint, row.PreferredQuantity,
                            row.IsLowStockWarningEnabled, row.LowStockWarningQuantity);
                    }

                    // 6. Stock quantity (into first warehouse when quantity > 0)
                    if (row.Quantity is > 0 && firstWarehouse != null)
                    {
                        if (stockByProduct.TryGetValue(product.Id, out var stock))
                            stock.UpdateDetails(row.Quantity.Value, firstWarehouse.Id, product.Id);
                        else
                        {
                            var ns = Stock.Create(row.Quantity.Value, firstWarehouse.Id, product.Id, companyId);
                            _db.Stocks.Add(ns);
                            stockByProduct[product.Id] = ns;
                        }
                    }

                    // Track for document creation
                    processedItems.Add((product, row.Quantity, row.TaxRate, row.IsTaxInclusivePrice));
                }
                catch (Exception ex)
                {
                    result.Errors.Add($"'{row.Name}': {ex.Message}");
                }
            }

            await _db.SaveChangesAsync(ct);

            // ---------------------------------------------------------------
            // Document creation
            // ---------------------------------------------------------------
            if (req.DocumentType != "none" && firstWarehouse != null && processedItems.Count > 0)
            {
                int docTypeId;
                string docTypeCode;
                if (req.DocumentType == "purchase")
                {
                    docTypeId = DocumentTypeConstants.Purchase;
                    docTypeCode = DocumentTypeConstants.PurchaseCode;
                }
                else // "inventoryCount" (default)
                {
                    docTypeId = DocumentTypeConstants.InventoryCount;
                    docTypeCode = DocumentTypeConstants.InventoryCountCode;
                }

                // Atomic counter increment
                string yy = DateTime.Now.ToString("yy");
                string counterKey = $"DOC_{yy}_{docTypeCode}_{companyId}";
                var counter = await _db.DocumentsCounter
                    .FirstOrDefaultAsync(c => c.Name == counterKey && c.CompanyId == companyId, ct);
                int nextValue;
                if (counter == null)
                {
                    nextValue = 1;
                    _db.DocumentsCounter.Add(DocumentsCounter.Create(counterKey, nextValue, companyId));
                }
                else
                {
                    nextValue = counter.Value + 1;
                    counter.UpdateValue(nextValue);
                }

                string docNumber = $"{yy}-{docTypeCode}-{nextValue.ToString().PadLeft(6, '0')}";
                string internalNote = $"Product import {DateTime.Now:dd/MM/yyyy HH:mm:ss}";

                int effectiveUserId = req.UserId > 0
                    ? req.UserId
                    : await _db.Users
                        .Where(u => u.CompanyId == companyId)
                        .OrderBy(u => u.Id)
                        .Select(u => u.Id)
                        .FirstOrDefaultAsync(ct);

                var document = Document.Create(
                    number: docNumber,
                    userId: effectiveUserId,
                    companyId: companyId,
                    documentTypeId: docTypeId,
                    warehouseId: firstWarehouse.Id,
                    total: 0,
                    paidStatus: 0,
                    internalNote: internalNote);

                _db.Documents.Add(document);
                await _db.SaveChangesAsync(ct); // flush to get Document.Id

                foreach (var (p, qty, taxRate, isTaxInclusive) in processedItems)
                {
                    decimal quantity = qty ?? 0;
                    decimal usePrice = req.DocumentType == "purchase" ? p.Cost : p.Price;

                    // Back-calculate price before tax when tax is inclusive
                    decimal priceBeforeTax = usePrice;
                    if (taxRate is > 0 && isTaxInclusive == true)
                        priceBeforeTax = Math.Round(usePrice / (1 + taxRate.Value / 100), 4);

                    decimal total = Math.Round(quantity * usePrice, 4);

                    _db.DocumentItems.Add(DocumentItem.Create(
                        companyId:                    companyId,
                        documentId:                   document.Id,
                        productId:                    p.Id,
                        quantity:                     quantity,
                        expectedQuantity:             quantity,
                        priceBeforeTax:               priceBeforeTax,
                        price:                        usePrice,
                        discount:                     0,
                        discountType:                 0,
                        productCost:                  p.Cost,
                        priceBeforeTaxAfterDiscount:  priceBeforeTax,
                        priceAfterDiscount:           usePrice,
                        total:                        total,
                        totalAfterDocumentDiscount:   total,
                        discountApplyRule:            false));
                }

                await _db.SaveChangesAsync(ct);
                result.DocumentNumber = docNumber;
            }

            return result;
        }
    }
}
