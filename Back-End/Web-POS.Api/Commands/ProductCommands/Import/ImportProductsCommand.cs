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

    /// <summary>
    /// Creates or merges products from a CSV/XML import, one row at a time.
    /// </summary>
    /// <remarks>
    /// 🚨 Each row is its own transaction, and a row that fails is rolled back AND
    /// taken out of the change tracker. It used to be neither: a row whose save
    /// threw — on SQL Server, a SKU longer than its column is "String or binary
    /// data would be truncated" — left its entity tracked in the Added state, so
    /// every later row's save retried it and failed too, and the final save threw
    /// a 500 for the whole import. Over-long cells are now caught before any save,
    /// and anything that still goes wrong costs that one row only.
    ///
    /// What a row asks for and cannot have is reported, not dropped: a barcode
    /// already on another product, a tax rate the company does not have, a
    /// supplier nobody by that name. Those used to vanish without a word.
    /// </remarks>
    public class ImportProductsCommandHandler
        : IRequestHandler<ImportProductsCommand, ImportProductsResult>
    {
        // Column limits the database enforces (Product / ProductGroup).
        private const int NameMax = 255;
        private const int CodeMax = 100;
        private const int UnitMax = 50;
        private const int ColorMax = 50;
        private const int GroupNameMax = 255;

        private readonly AppDbContext _db;
        public ImportProductsCommandHandler(AppDbContext db) => _db = db;

        public async Task<ImportProductsResult> Handle(
            ImportProductsCommand command,
            CancellationToken ct)
        {
            var req = command.Request;
            var result = new ImportProductsResult();
            var cache = await CatalogCache.LoadAsync(_db, req.CompanyId, ct);
            var strategy = _db.Database.CreateExecutionStrategy();

            // Only rows that were committed feed the document.
            var processedItems = new List<(Product product, decimal? quantity, decimal? taxRate, bool? isTaxInclusive)>();

            foreach (var row in req.Rows)
            {
                if (string.IsNullOrWhiteSpace(row.Name)) continue;
                var label = row.Name.Trim();

                var invalid = Validate(row);
                if (invalid != null)
                {
                    result.Errors.Add($"'{Short(label)}': {invalid}");
                    continue;
                }

                var isDuplicate = cache.Products.ContainsKey(Key(label));
                if (isDuplicate && (req.SkipDuplicates || !req.MergeDuplicates))
                {
                    result.Skipped++;
                    continue;
                }

                var journal = new RowJournal();
                try
                {
                    await strategy.ExecuteAsync(async () =>
                    {
                        // A retried attempt must not inherit the failed one's changes.
                        await journal.ResetAsync(_db, ct);
                        await using var tx = await _db.Database.BeginTransactionAsync(ct);
                        await ImportRowAsync(row, req.CompanyId, cache, journal, ct);
                        await _db.SaveChangesAsync(ct);
                        await tx.CommitAsync(ct);
                    });
                }
                catch (Exception ex)
                {
                    await journal.RollBackAsync(_db, ct);
                    result.Errors.Add($"'{Short(label)}': {Innermost(ex).Message}");
                    continue;
                }

                cache.Absorb(journal);
                if (journal.Outcome == RowOutcome.Created) result.Created++;
                else result.Updated++;
                result.Warnings.AddRange(journal.Warnings.Select(w => $"'{Short(label)}': {w}"));
                processedItems.Add((journal.Product!, row.Quantity, row.TaxRate, row.IsTaxInclusivePrice));
            }

            // ---------------------------------------------------------------
            // Document creation
            // ---------------------------------------------------------------
            if (req.DocumentType != "none" && cache.FirstWarehouse != null && processedItems.Count > 0)
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
                string counterKey = $"DOC_{yy}_{docTypeCode}_{req.CompanyId}";
                var counter = await _db.DocumentsCounter
                    .FirstOrDefaultAsync(c => c.Name == counterKey && c.CompanyId == req.CompanyId, ct);
                int nextValue;
                if (counter == null)
                {
                    nextValue = 1;
                    _db.DocumentsCounter.Add(DocumentsCounter.Create(counterKey, nextValue, req.CompanyId));
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
                        .Where(u => u.CompanyId == req.CompanyId)
                        .OrderBy(u => u.Id)
                        .Select(u => u.Id)
                        .FirstOrDefaultAsync(ct);

                var document = Document.Create(
                    number: docNumber,
                    userId: effectiveUserId,
                    companyId: req.CompanyId,
                    documentTypeId: docTypeId,
                    warehouseId: cache.FirstWarehouse.Id,
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
                        companyId:                    req.CompanyId,
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

        // ── One row ──────────────────────────────────────────────────────────

        private async Task ImportRowAsync(
            ImportProductRow row, int companyId, CatalogCache cache, RowJournal j, CancellationToken ct)
        {
            // 1. Group
            var groupId = await ResolveGroupAsync(row, companyId, cache, j, ct);

            // 2. Product
            var code = Clean(row.Code);
            var unitText = Clean(row.MeasurementUnit);
            if (cache.Products.TryGetValue(Key(row.Name), out var existing))
            {
                // A spreadsheet has no UoM id column, so the unit is derived from
                // the text the row carries. A row that names no unit must leave the
                // product's unit alone — re-deriving it would file every re-import
                // under pieces.
                var importedUomId = unitText != null
                    ? UnitOfMeasure.FromLegacyText(unitText)
                    : existing.UomId;

                j.Touch(existing);
                existing.Update(
                    productGroupId:        groupId ?? existing.ProductGroupId,
                    name:                  existing.Name,
                    code:                  code ?? existing.Code,
                    plu:                   existing.PLU,
                    measurementUnit:       unitText ?? existing.MeasurementUnit,
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
                    color:                 Clean(row.Color) ?? existing.Color,
                    ageRestriction:        existing.AgeRestriction,
                    lastPurchasePrice:     existing.LastPurchasePrice,
                    rank:                  existing.Rank,
                    uomId:                 importedUomId,
                    isToWeigh:             row.IsToWeigh || existing.IsToWeigh,
                    // Same rule as the unit: a row that says nothing keeps what the
                    // product had. Normalised against the unit the row just chose,
                    // so a re-import that moves a product off box does not leave a
                    // pack size behind to be believed.
                    packSize:              UnitOfMeasure.NormalisePackSize(
                                               importedUomId,
                                               row.PackSize ?? existing.PackSize));
                j.Product = existing;
                j.Outcome = RowOutcome.Updated;
            }
            else
            {
                var uomId = UnitOfMeasure.FromLegacyText(unitText);
                var product = Product.Create(
                    productGroupId:        groupId,
                    name:                  row.Name.Trim(),
                    code:                  code,
                    plu:                   null,
                    measurementUnit:       unitText,
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
                    color:                 Clean(row.Color) ?? "Transparent",
                    ageRestriction:        null,
                    lastPurchasePrice:     null,
                    rank:                  0,
                    uomId:                 uomId,
                    isToWeigh:             row.IsToWeigh,
                    packSize:              UnitOfMeasure.NormalisePackSize(uomId, row.PackSize));
                product.CompanyId = companyId;
                _db.Products.Add(product);
                j.Created.Add(product);
                await _db.SaveChangesAsync(ct); // its id is needed below
                j.Product = product;
                j.Outcome = RowOutcome.Created;
            }

            var p = j.Product;

            // 3. Tax
            if (row.TaxRate.HasValue)
            {
                if (!cache.TaxesByRate.TryGetValue(row.TaxRate.Value, out var tax))
                {
                    j.Warnings.Add($"no tax at {row.TaxRate.Value:0.####}% in this company — imported without a tax");
                }
                else if (!cache.ProductTaxes.Contains((p.Id, tax.Id)) && j.NewProductTaxes.Add((p.Id, tax.Id)))
                {
                    var pt = ProductTax.Create(p.Id, tax.Id, companyId);
                    _db.ProductsTaxes.Add(pt);
                    j.Created.Add(pt);
                }
            }

            // 4. Barcodes — every one on the row, never one stolen from another product.
            foreach (var value in BarcodesOf(row))
            {
                if (cache.BarcodeOwner.TryGetValue(value, out var ownerId)
                    || j.NewBarcodes.TryGetValue(value, out ownerId))
                {
                    if (ownerId != p.Id)
                        j.Warnings.Add($"barcode {value} already belongs to another product — not added");
                    continue;
                }
                var barcode = Barcode.Create(value, p.Id, companyId);
                _db.Barcodes.Add(barcode);
                j.Created.Add(barcode);
                j.NewBarcodes[value] = p.Id;
            }

            // 5. Stock control
            int? supplierId = null;
            var supplierName = Clean(row.SupplierName);
            if (supplierName != null)
            {
                if (cache.Suppliers.TryGetValue(Key(supplierName), out var supplier)) supplierId = supplier.Id;
                else j.Warnings.Add($"no supplier named '{supplierName}' — imported without one");
            }

            if (supplierId.HasValue || row.ReorderPoint.HasValue ||
                row.PreferredQuantity.HasValue || row.IsLowStockWarningEnabled.HasValue ||
                row.LowStockWarningQuantity.HasValue)
            {
                if (cache.StockControls.TryGetValue(p.Id, out var sc))
                {
                    j.Touch(sc);
                }
                else
                {
                    sc = StockControl.Create(p.Id, companyId);
                    _db.StockControls.Add(sc);
                    j.Created.Add(sc);
                    j.NewStockControl = sc;
                }

                // A column the file does not have keeps what the product already
                // had. Passing the row's nulls straight through wiped the supplier
                // (and the rest) on every merge that did not repeat them.
                sc.Update(
                    supplierId ?? sc.CustomerId,
                    row.ReorderPoint ?? sc.ReorderPoint,
                    row.PreferredQuantity ?? sc.PreferredQuantity,
                    row.IsLowStockWarningEnabled ?? sc.IsLowStockWarningEnabled,
                    row.LowStockWarningQuantity ?? sc.LowStockWarningQuantity);
            }

            // 6. Stock quantity (into the first warehouse when quantity > 0)
            if (row.Quantity is > 0 && cache.FirstWarehouse != null)
            {
                if (cache.Stocks.TryGetValue(p.Id, out var stock))
                {
                    j.Touch(stock);
                    stock.UpdateDetails(row.Quantity.Value, cache.FirstWarehouse.Id, p.Id);
                }
                else
                {
                    var created = Stock.Create(row.Quantity.Value, cache.FirstWarehouse.Id, p.Id, companyId);
                    _db.Stocks.Add(created);
                    j.Created.Add(created);
                    j.NewStock = created;
                }
            }
        }

        /// <summary>
        /// The group a row belongs in. Names are unique per company, so the leaf's
        /// name alone finds an existing group — which is used where it is; an import
        /// never moves one. Only a leaf that does not exist yet is built, along with
        /// any missing link of <see cref="ImportProductRow.ProductGroupPath"/>
        /// above it, each under the one before.
        /// </summary>
        private async Task<int?> ResolveGroupAsync(
            ImportProductRow row, int companyId, CatalogCache cache, RowJournal j, CancellationToken ct)
        {
            var chain = GroupChainOf(row);
            if (chain.Count == 0) return null;

            ProductGroup? Find(string name) =>
                cache.Groups.TryGetValue(Key(name), out var g) || j.NewGroups.TryGetValue(Key(name), out g) ? g : null;

            var leaf = Find(chain[^1]);
            if (leaf != null) return leaf.Id;

            int? parentId = null;
            foreach (var name in chain)
            {
                var group = Find(name);
                if (group == null)
                {
                    group = ProductGroup.Create(name, parentId, "Transparent", null, 0, companyId);
                    _db.ProductGroups.Add(group);
                    j.Created.Add(group);
                    j.NewGroups[Key(name)] = group;
                    await _db.SaveChangesAsync(ct); // the next link and the product need its id
                }
                parentId = group.Id;
            }
            return parentId;
        }

        // ── Helpers ──────────────────────────────────────────────────────────

        private static string? Validate(ImportProductRow row)
        {
            if (row.Name.Trim().Length > NameMax) return $"the name is longer than {NameMax} characters";
            if (Clean(row.Code)?.Length > CodeMax) return $"the SKU is longer than {CodeMax} characters";
            if (Clean(row.MeasurementUnit)?.Length > UnitMax)
                return $"the measurement unit is longer than {UnitMax} characters";
            if (Clean(row.Color)?.Length > ColorMax)
                return $"the colour is longer than {ColorMax} characters";
            if (GroupChainOf(row).Any(g => g.Length > GroupNameMax))
                return $"a group name is longer than {GroupNameMax} characters";
            return null;
        }

        private static List<string> GroupChainOf(ImportProductRow row)
        {
            var chain = (row.ProductGroupPath ?? [])
                .Select(Clean)
                .Where(s => s != null)
                .Select(s => s!)
                .ToList();
            if (chain.Count == 0 && Clean(row.ProductGroupName) is { } leaf) chain.Add(leaf);
            return chain;
        }

        private static IEnumerable<string> BarcodesOf(ImportProductRow row) =>
            (row.Barcodes ?? [])
                .Append(row.Barcode)
                .Select(Clean)
                .Where(b => b != null)
                .Select(b => b!)
                .Distinct(StringComparer.Ordinal);

        private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

        private static string Key(string s) => s.Trim().ToLowerInvariant();

        private static string Short(string s) => s.Length > 60 ? s[..60] + "…" : s;

        private static Exception Innermost(Exception ex)
        {
            while (ex.InnerException != null) ex = ex.InnerException;
            return ex;
        }

        // ── What the import knows about the company, loaded once ─────────────

        private sealed class CatalogCache
        {
            public Dictionary<string, ProductGroup> Groups { get; private init; } = new();
            public Dictionary<string, Product> Products { get; private init; } = new();
            public Dictionary<decimal, Tax> TaxesByRate { get; private init; } = new();
            public Dictionary<string, int> BarcodeOwner { get; } = new(StringComparer.Ordinal);
            public HashSet<(int ProductId, int TaxId)> ProductTaxes { get; private init; } = new();
            public Dictionary<int, StockControl> StockControls { get; private init; } = new();
            public Dictionary<string, Customer> Suppliers { get; private init; } = new();
            public Warehouse? FirstWarehouse { get; private init; }
            public Dictionary<int, Stock> Stocks { get; private init; } = new();

            public static async Task<CatalogCache> LoadAsync(AppDbContext db, int companyId, CancellationToken ct)
            {
                var firstWarehouse = await db.Warehouses
                    .Where(w => w.CompanyId == companyId)
                    .OrderBy(w => w.Id)
                    .FirstOrDefaultAsync(ct);

                var cache = new CatalogCache
                {
                    // Lower-cased names CAN collide — two suppliers called "Atlas", a
                    // "coke" beside a "Coke". The first by id wins instead of
                    // ToDictionary throwing and failing the WHOLE import with a 500.
                    Groups = FirstByKey(
                        await db.ProductGroups.Where(g => g.CompanyId == companyId).ToListAsync(ct),
                        g => g.Name, g => g.Id),
                    Products = FirstByKey(
                        await db.Products.Where(p => p.CompanyId == companyId).ToListAsync(ct),
                        p => p.Name, p => p.Id),
                    Suppliers = FirstByKey(
                        await db.Customers
                            .Where(c => c.CompanyId == companyId && c.IsSupplier && c.Name != null)
                            .ToListAsync(ct),
                        c => c.Name, c => c.Id),
                    TaxesByRate = (await db.Taxes.Where(t => t.CompanyId == companyId).ToListAsync(ct))
                        .GroupBy(t => t.Rate)
                        .ToDictionary(g => g.Key, g => g.OrderBy(t => t.Id).First()),
                    ProductTaxes = (await db.ProductsTaxes
                            .Where(pt => pt.CompanyId == companyId)
                            .Select(pt => new { pt.ProductId, pt.TaxId })
                            .ToListAsync(ct))
                        .Select(x => (x.ProductId, x.TaxId))
                        .ToHashSet(),
                    StockControls = (await db.StockControls.Where(sc => sc.CompanyId == companyId).ToListAsync(ct))
                        .GroupBy(sc => sc.ProductId)
                        .ToDictionary(g => g.Key, g => g.First()),
                    FirstWarehouse = firstWarehouse,
                    Stocks = firstWarehouse == null
                        ? new()
                        : (await db.Stocks
                                .Where(s => s.CompanyId == companyId && s.WarehouseId == firstWarehouse.Id)
                                .ToListAsync(ct))
                            .GroupBy(s => s.ProductId)
                            .ToDictionary(g => g.Key, g => g.First()),
                };

                foreach (var b in await db.Barcodes
                             .Where(b => b.CompanyId == companyId && b.Value != null)
                             .Select(b => new { b.Value, b.ProductId })
                             .ToListAsync(ct))
                {
                    cache.BarcodeOwner.TryAdd(b.Value!, b.ProductId);
                }

                return cache;
            }

            /// <summary>Makes a committed row visible to the rows after it.</summary>
            public void Absorb(RowJournal j)
            {
                foreach (var (key, group) in j.NewGroups) Groups.TryAdd(key, group);
                if (j.Outcome == RowOutcome.Created && j.Product != null)
                    Products.TryAdd(Key(j.Product.Name), j.Product);
                foreach (var (value, productId) in j.NewBarcodes) BarcodeOwner.TryAdd(value, productId);
                foreach (var pt in j.NewProductTaxes) ProductTaxes.Add(pt);
                if (j.NewStockControl != null) StockControls.TryAdd(j.NewStockControl.ProductId, j.NewStockControl);
                if (j.NewStock != null) Stocks.TryAdd(j.NewStock.ProductId, j.NewStock);
            }

            private static Dictionary<string, T> FirstByKey<T>(
                IEnumerable<T> items, Func<T, string?> name, Func<T, int> id) =>
                items
                    .Where(i => !string.IsNullOrWhiteSpace(name(i)))
                    .GroupBy(i => Key(name(i)!))
                    .ToDictionary(g => g.Key, g => g.OrderBy(id).First());
        }

        // ── What one row did, so it can be undone ────────────────────────────

        private enum RowOutcome { Created, Updated }

        private sealed class RowJournal
        {
            private bool _attempted;

            /// <summary>Entities this row added.</summary>
            public List<object> Created { get; } = [];

            /// <summary>Entities that already existed and this row changed.</summary>
            public List<object> Touched { get; } = [];

            public Dictionary<string, ProductGroup> NewGroups { get; } = new();
            public Dictionary<string, int> NewBarcodes { get; } = new(StringComparer.Ordinal);
            public HashSet<(int ProductId, int TaxId)> NewProductTaxes { get; } = [];
            public StockControl? NewStockControl { get; set; }
            public Stock? NewStock { get; set; }
            public List<string> Warnings { get; } = [];
            public Product? Product { get; set; }
            public RowOutcome Outcome { get; set; }

            public void Touch(object entity)
            {
                if (!Touched.Contains(entity)) Touched.Add(entity);
            }

            /// <summary>The first attempt starts as it is; a retry starts from nothing.</summary>
            public async Task ResetAsync(AppDbContext db, CancellationToken ct)
            {
                if (_attempted) await RollBackAsync(db, ct);
                _attempted = true;
            }

            /// <summary>
            /// Takes this row back out of the change tracker: what it added is
            /// detached, what it changed is reloaded from the database. Without this
            /// the failed row's entities rode along with every later save.
            /// </summary>
            public async Task RollBackAsync(AppDbContext db, CancellationToken ct)
            {
                foreach (var entity in Created) db.Entry(entity).State = EntityState.Detached;
                foreach (var entity in Touched)
                {
                    var entry = db.Entry(entity);
                    if (entry.State != EntityState.Detached) await entry.ReloadAsync(ct);
                }

                Created.Clear();
                Touched.Clear();
                NewGroups.Clear();
                NewBarcodes.Clear();
                NewProductTaxes.Clear();
                NewStockControl = null;
                NewStock = null;
                Warnings.Clear();
                Product = null;
            }
        }
    }
}
