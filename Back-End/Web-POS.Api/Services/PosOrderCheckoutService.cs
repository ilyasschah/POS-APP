using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Services
{
    public class PosOrderCheckoutService
    {
        private readonly AppDbContext _db;
        private readonly DocumentsCounterRepository _counterRepo;
        private readonly ILogger<PosOrderCheckoutService> _logger;

        public PosOrderCheckoutService(
            AppDbContext db,
            DocumentsCounterRepository counterRepo,
            ILogger<PosOrderCheckoutService> logger)
        {
            _db = db;
            _counterRepo = counterRepo;
            _logger = logger;
        }

        /// <summary>
        /// Splits the document-level reduction across a sale's lines so that
        /// <c>SUM(DocumentItem.TotalAfterDocumentDiscount) == Document.Total</c>.
        ///
        /// That column is the revenue figure every sales view sums —
        /// vw_DashboardSalesData, vw_SalesByProduct, vw_SalesByTax, vw_ProfitRow,
        /// vw_SalesItemList. Clients send a per-line value for it, but despite the
        /// name it only ever reflected the ITEM discount: nothing subtracted the
        /// order-level reduction, so all of those reports read gross instead of
        /// collected. Measured on 2026-08-06: the dashboard said 96.00 where the
        /// documents and the payments said 85.00 — an 8.00 manual cart discount
        /// plus a 3.00 loyalty-points redemption.
        ///
        /// Derived from <paramref name="grandTotal"/> rather than from
        /// Document.Discount on purpose. Only the manual cart discount reaches that
        /// column; loyalty points and promotions land in DiscountLine instead, and
        /// leave Document.Discount at 0. The grand total is already net of every
        /// source, so reconciling to it covers them all without this method having
        /// to enumerate them.
        ///
        /// The remainder lands on the last line rather than rounding every share,
        /// so the column sums EXACTLY to the header — rounding per line drifts by a
        /// cent and leaves the reports permanently disagreeing with the documents.
        /// </summary>
        private static decimal[] ApportionDocumentDiscount(
            IReadOnlyList<decimal> lineTotals, decimal grandTotal)
        {
            var result = new decimal[lineTotals.Count];
            decimal gross = 0;
            for (var i = 0; i < lineTotals.Count; i++) gross += lineTotals[i];

            // Only ever a reduction. When the grand total meets or exceeds the line
            // gross — tax-exclusive pricing adding tax on top, or a payload we
            // can't reconcile — every line keeps its own total.
            var discount = gross - grandTotal;
            if (gross <= 0 || discount <= 0)
            {
                for (var i = 0; i < lineTotals.Count; i++) result[i] = lineTotals[i];
                return result;
            }
            if (discount > gross) discount = gross;

            decimal allocated = 0;
            for (var i = 0; i < lineTotals.Count; i++)
            {
                decimal share;
                if (i == lineTotals.Count - 1)
                {
                    share = discount - allocated;
                }
                else
                {
                    share = Math.Round(discount * lineTotals[i] / gross, 2,
                        MidpointRounding.AwayFromZero);
                    allocated += share;
                }
                result[i] = lineTotals[i] - share;
            }
            return result;
        }

        public async Task<CheckoutResult> CheckoutAsync(int companyId, int userId, CheckoutPosOrderRequest req)
        {
            var strategy = _db.Database.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _db.Database.BeginTransactionAsync();

                try
                {
                    var posOrder = await _db.PosOrders
                        .FirstOrDefaultAsync(o => o.Id == req.PosOrderId && o.CompanyId == companyId);

                    if (posOrder == null)
                        throw new InvalidOperationException("Order not found.");

                    var posOrderItems = await _db.PosOrderItems
                        .Where(i => i.PosOrderId == req.PosOrderId && i.VoidedBy == null)
                        .ToListAsync();

                    if (!posOrderItems.Any() || req.Items == null || !req.Items.Any())
                        throw new InvalidOperationException("Cannot checkout an empty order.");

                    var posOrderItemIds = posOrderItems.Select(i => i.Id).ToList();
                    var cartTaxes = await _db.PosOrderItemTaxes
                        .Where(t => posOrderItemIds.Contains(t.PosOrderItemId) && t.CompanyId == companyId)
                        .ToListAsync();

                    decimal documentGrandTotal = req.GrandTotal;

                    // The client is responsible for sending a valid warehouse.
                    // As a safety net (e.g. a re-opened order whose warehouse
                    // context was lost), fall back to any warehouse belonging to
                    // the company so the Document's FK never fails.
                    int warehouseId = req.WarehouseId;
                    if (warehouseId <= 0 || !await _db.Warehouses.AnyAsync(w => w.Id == warehouseId))
                    {
                        warehouseId = await _db.Warehouses
                            .AsNoTracking()
                            .Where(w => w.CompanyId == companyId)
                            .Select(w => (int?)w.Id)
                            .FirstOrDefaultAsync()
                            ?? throw new InvalidOperationException($"Warehouse {req.WarehouseId} not found and company {companyId} has no warehouse to fall back to.");
                    }

                    string documentNumber;
                    if (!string.IsNullOrWhiteSpace(req.ClientDocumentNumber))
                    {
                        // Offline-first: the client issued a device-local number at
                        // checkout (e.g. CAISSE1-200-000045). Keep it verbatim so the
                        // printed/scanned receipt never changes after sync — and no
                        // server counter is consumed (the device owns its sequence).
                        //
                        // …unless the company already holds that number, in which
                        // case the client's choice CANNOT be honoured:
                        // UQ_Document_Number_PerCompany rejects the insert and the
                        // sale is stuck as "failed" forever, which is how a real
                        // terminal ended up unable to bank two offline sales.
                        //
                        // The client's number is a PREFERENCE; the server owns
                        // uniqueness, because only the server can see every
                        // terminal's numbers. A collision is not hypothetical — a
                        // restored backup rolls the device's counter back, and the
                        // sales rung up afterwards re-issue numbers the cloud has
                        // already consumed for DIFFERENT sales.
                        documentNumber = await ResolveFreeDocumentNumberAsync(
                            companyId, req.ClientDocumentNumber.Trim());
                    }
                    else
                    {
                        // Online / legacy path: generate the server sequence YY-CCC-NNNNNN.
                        string yy = DateTime.UtcNow.ToString("yy");
                        string counterKey = $"DOC_{yy}_{DocumentTypeConstants.SalesCode}_{companyId}";
                        var counter = await _counterRepo.GetByNameAsync(counterKey, trackEntity: true);
                        int nextValue;
                        if (counter == null)
                        {
                            nextValue = 1;
                            var newCounter = DocumentsCounter.Create(counterKey, nextValue, companyId);
                            await _counterRepo.AddAsync(newCounter);
                        }
                        else
                        {
                            nextValue = counter.Value + 1;
                            counter.UpdateValue(nextValue);
                            await _counterRepo.UpdateAsync(counter);
                        }
                        documentNumber = $"{yy}-{DocumentTypeConstants.SalesCode}-{nextValue.ToString().PadLeft(6, '0')}";
                    }

                    // Default null customer to Walk-In (Code = "C000")
                    int? effectiveCustomerId = posOrder.CustomerId;
                    if (effectiveCustomerId == null || effectiveCustomerId == 0)
                    {
                        effectiveCustomerId = await _db.Customers
                            .Where(c => c.CompanyId == companyId && c.Code == "C000")
                            .Select(c => (int?)c.Id)
                            .FirstOrDefaultAsync();
                    }

                    // Rule 2: respect the PaymentType's MarkAsPaid flag so that
                    // credit/tab payment types leave the document as Unpaid (0).
                    var paymentType = await _db.PaymentTypes
                        .AsNoTracking()
                        .FirstOrDefaultAsync(pt => pt.Id == req.PaymentTypeId);
                    int paidStatus = (paymentType?.MarkAsPaid ?? true) ? 1 : 0;

                    // Rule 3: calculate DueDate from the DefaultDueDateDays setting.
                    var dueDateProp = await _db.ApplicationProperties
                        .Where(ap => ap.CompanyId == companyId && ap.Name == "Order.DefaultDueDateDays")
                        .Select(ap => ap.Value)
                        .FirstOrDefaultAsync();
                    int dueDateDays = int.TryParse(dueDateProp, out var parsedDays) ? parsedDays : 0;
                    DateTime? calculatedDueDate = dueDateDays > 0
                        ? DateTime.UtcNow.Date.AddDays(dueDateDays)
                        : (DateTime?)null;

                    var document = Document.Create(
                        number: documentNumber,
                        userId: userId,
                        companyId: companyId,
                        documentTypeId: req.DocumentTypeId,
                        warehouseId: warehouseId,
                        total: documentGrandTotal,
                        customerId: effectiveCustomerId,
                        orderNumber: req.OrderNumber ?? posOrder.Number,
                        discount: posOrder.Discount,
                        discountType: posOrder.DiscountType,
                        paidStatus: paidStatus,
                        serviceType: posOrder.ServiceType,
                        dueDate: calculatedDueDate
                    );

                    _db.Documents.Add(document);
                    await _db.SaveChangesAsync(); 
                    var productIds = posOrderItems.Select(i => i.ProductId).Distinct().ToList();
                    var productCosts = await _db.Products
                        .Where(p => productIds.Contains(p.Id) && p.CompanyId == companyId)
                        .ToDictionaryAsync(p => p.Id, p => p.Cost);
                    // Map each created DocumentItem back to the client's stable line
                    // id so the offline client can stamp its local document_items row.
                    var itemServerIds = new Dictionary<string, int>();
                    // Consume each PosOrderItem at most once. Matching by ProductId
                    // alone collapsed duplicate-product / split-sourcing lines onto the
                    // first row (wrong quantities, lost lines); claiming the first
                    // UNUSED match keeps each cart line distinct. req.Items and
                    // posOrderItems derive from the same client list, so same-product
                    // lines stay in order.
                    var consumedItemIds = new HashSet<int>();
                    var lines = new List<(CheckoutItemDto Dto, PosOrderItem Cart)>(req.Items.Count);
                    foreach (var frontendItem in req.Items)
                    {
                        var originalCartItem = posOrderItems.FirstOrDefault(
                            i => i.ProductId == frontendItem.ProductId && !consumedItemIds.Contains(i.Id));
                        if (originalCartItem == null) continue;
                        consumedItemIds.Add(originalCartItem.Id);
                        lines.Add((frontendItem, originalCartItem));
                    }

                    // Resolve the lines first (above) so the split below runs over
                    // exactly the rows that reach the table — the rounding remainder
                    // has to land on a line that actually gets persisted.
                    var netTotals = ApportionDocumentDiscount(
                        lines.Select(l => l.Dto.Total).ToList(), documentGrandTotal);

                    for (var idx = 0; idx < lines.Count; idx++)
                    {
                        var (frontendItem, originalCartItem) = lines[idx];

                        var docItem = DocumentItem.Create(
                            companyId: companyId,
                            documentId: document.Id,
                            productId: originalCartItem.ProductId,
                            quantity: originalCartItem.Quantity,
                            expectedQuantity: originalCartItem.Quantity,
                            priceBeforeTax: originalCartItem.Price,
                            price: originalCartItem.Price,
                            discount: originalCartItem.Discount,
                            discountType: originalCartItem.DiscountType,
                            productCost: productCosts.ContainsKey(originalCartItem.ProductId) ? productCosts[originalCartItem.ProductId] : 0,
                            priceBeforeTaxAfterDiscount: frontendItem.PriceBeforeTaxAfterDiscount,
                            priceAfterDiscount: frontendItem.PriceAfterDiscount,
                            total: frontendItem.Total,
                            // Recomputed, not taken from the payload — see
                            // ApportionDocumentDiscount.
                            totalAfterDocumentDiscount: netTotals[idx],
                            discountApplyRule: false
                        );

                        _db.DocumentItems.Add(docItem);
                        await _db.SaveChangesAsync();

                        if (!string.IsNullOrEmpty(frontendItem.LineLocalId))
                            itemServerIds[frontendItem.LineLocalId] = docItem.Id;

                        if (frontendItem.Taxes != null && frontendItem.Taxes.Any())
                        {
                            foreach (var taxDto in frontendItem.Taxes)
                            {
                                var docTax = DocumentItemTax.Create(
                                    documentItemId: docItem.Id,
                                    taxId: taxDto.TaxId,
                                    amount: taxDto.Amount,
                                    companyId: companyId
                                );
                                _db.Add(docTax);
                            }
                        }
                    }

                    await _db.SaveChangesAsync();

                    // Normalized discount breakdown — one DiscountLine per source,
                    // linked to the Document. Optional: legacy/online callers send
                    // none, so the loop is simply skipped.
                    if (req.Discounts != null && req.Discounts.Any())
                    {
                        foreach (var d in req.Discounts)
                        {
                            _db.Add(DiscountLine.Create(
                                companyId: companyId,
                                documentId: document.Id,
                                productId: d.ProductId,
                                source: d.Source,
                                sourceRefId: d.SourceRefId,
                                value: d.Value,
                                valueType: d.ValueType,
                                amount: d.Amount,
                                sequence: d.Sequence,
                                label: d.Label));
                        }
                        await _db.SaveChangesAsync();
                    }

                    var payment = Payment.Create(
                        companyId: companyId,
                        documentId: document.Id,
                        paymentTypeId: req.PaymentTypeId,
                        amount: req.AmountPaid,
                        userId: userId
                    );
                    _db.Payments.Add(payment);

                    // ── POS SESSION ────────────────────────────────────────
                    // The sale belongs to the drawer that took it, and the link
                    // is resolved from the CLIENT's localId: a sale rung up
                    // offline may belong to a session that was itself opened
                    // offline and has no server id the device could have sent.
                    //
                    // 🚨 Fails OPEN. An unknown, missing, or malformed session
                    // banks the sale unattached instead of rejecting money that
                    // has already changed hands — the same rule the client's
                    // session gate follows. Without this the session's own
                    // reconciliation saw no payments at all and every register
                    // closed against its opening float alone.
                    if (!string.IsNullOrWhiteSpace(req.SessionLocalId))
                    {
                        var session = await _db.Shifts.FirstOrDefaultAsync(s =>
                            s.LocalId == req.SessionLocalId &&
                            s.CompanyId == companyId);

                        if (session != null)
                        {
                            // A sale that lands after its session was reported
                            // keeps the session it belongs to — hiding it would
                            // lose the sale, moving it would corrupt two
                            // reports. It is flagged instead, so the difference
                            // is visible and can be reconciled.
                            var arrivedAfterClose =
                                session.Status == PosSessionStatus.Closed;

                            document.AttachToSession(session.Id, arrivedAfterClose);
                            payment.AttachToSession(session.Id);
                            if (arrivedAfterClose) session.MarkLateArrival();
                        }
                    }

                    if (cartTaxes.Any())
                        _db.PosOrderItemTaxes.RemoveRange(cartTaxes);

                    _db.PosOrderItems.RemoveRange(posOrderItems);

                    var booking = await _db.Bookings
                        .FirstOrDefaultAsync(b => b.PosOrderId == posOrder.Id && b.CompanyId == companyId);

                    if (booking != null)
                    {
                        booking.UpdateStatus(4, document.Id); // Completed + link receipt
                        foreach (var tableId in booking.TableIds)
                        {
                            var t = await _db.FloorPlanTables.FirstOrDefaultAsync(t => t.Id == tableId && t.CompanyId == companyId);
                            if (t != null) { t.UpdateStatus(0); _db.FloorPlanTables.Update(t); }
                        }
                    }
                    else if (posOrder.FloorPlanTableId.HasValue)
                    {
                        var table = await _db.FloorPlanTables.FirstOrDefaultAsync(t => t.Id == posOrder.FloorPlanTableId.Value && t.CompanyId == companyId);
                        if (table != null) { table.UpdateStatus(0); _db.FloorPlanTables.Update(table); }
                    }

                    _db.PosOrders.Remove(posOrder);
                    await _db.SaveChangesAsync();
                    await transaction.CommitAsync();

                    return new CheckoutResult
                    {
                        DocumentId = document.Id,
                        ItemServerIds = itemServerIds,
                    };
                }
                catch (Exception)
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            });
        }

        /// <summary>
        /// Returns <paramref name="requested"/> when the company does not already
        /// hold that document number, otherwise the next free number in the same
        /// series.
        /// </summary>
        /// <remarks>
        /// Guards <c>UQ_Document_Number_PerCompany</c>. Without it a colliding
        /// number makes the whole checkout throw, and an offline sale can never be
        /// banked — it just retries and fails forever.
        /// <para>
        /// ⚠️ It deliberately does NOT try to detect "this is the same sale being
        /// re-sent" and dedupe. It cannot: the schema carries no client-side id on
        /// Document, so same-sale and different-sale look identical here, and
        /// guessing wrong either double-banks takings or discards them. Issuing a
        /// new number is the only choice that can never LOSE a sale — the worst
        /// case is a duplicate an operator can see and void, rather than money
        /// that quietly disappeared. (A `ClientLocalId` column on Document would
        /// make this exact; that is a schema change and needs sign-off.)
        /// </para>
        /// <para>
        /// The receipt already printed keeps the old number. That is unavoidable
        /// once the number is taken, and is why the reassignment is logged.
        /// </para>
        /// </remarks>
        private async Task<string> ResolveFreeDocumentNumberAsync(
            int companyId, string requested)
        {
            var taken = await _db.Documents
                .AsNoTracking()
                .AnyAsync(d => d.CompanyId == companyId && d.Number == requested);
            if (!taken) return requested;

            // Split a trailing numeric run so PREFIX-000004 → ("PREFIX-", 4, 6).
            // Anything without one (a hand-typed number) just gets "-2", "-3"…
            var match = System.Text.RegularExpressions.Regex.Match(
                requested, @"^(?<prefix>.*?)(?<digits>\d+)$");

            var existing = await _db.Documents
                .AsNoTracking()
                .Where(d => d.CompanyId == companyId)
                .Select(d => d.Number)
                .ToListAsync();
            var used = new HashSet<string>(existing, StringComparer.OrdinalIgnoreCase);

            string candidate;
            if (match.Success)
            {
                var prefix = match.Groups["prefix"].Value;
                var digits = match.Groups["digits"].Value;
                var width = digits.Length;
                var n = long.Parse(digits);
                do
                {
                    n++;
                    candidate = prefix + n.ToString().PadLeft(width, '0');
                } while (used.Contains(candidate));
            }
            else
            {
                var suffix = 1;
                do
                {
                    suffix++;
                    candidate = $"{requested}-{suffix}";
                } while (used.Contains(candidate));
            }

            // ⚠️ Each placeholder EXACTLY once, and the count must match the
            // argument list. Microsoft.Extensions.Logging templates are
            // positional, not named: repeating {Requested} adds a fourth slot,
            // and with three arguments the formatter throws FormatException.
            // That is not a cosmetic bug here — the throw propagated out of
            // this method and aborted the checkout, so the very sale this
            // routine exists to rescue failed to bank.
            _logger.LogWarning(
                "Document number {Requested} already exists for company {CompanyId}; " +
                "the incoming sale was banked as {Assigned} instead (the printed " +
                "receipt still shows the original number).",
                requested, companyId, candidate);

            return candidate;
        }
    }
}