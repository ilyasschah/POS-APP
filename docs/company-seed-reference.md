# What a brand-new company is seeded with

Everything below is written by **one call**, inside the transaction that creates
the company:

```
POST /api/Company  ->  CompanyService.Create()
                         └─ CompanyDefaultsSeeder.SeedAsync(db, companyId)
                              └─ BarcodeRuleSeeder.SeedAsync(db, companyId)
```

Source of truth: `Back-End/Web-POS.Api/Services/CompanyDefaultsSeeder.cs`.
This file is a **reference, not an input** — nothing reads it. If the seeder
changes, regenerate this.

Every block is idempotent: the seeder only adds what is missing, so it can be
re-run against an existing company without collisions. `SeedAsync` is also
re-invoked at API startup via `DatabaseBootstrapper`, which is how settings and
security keys added in a later release reach companies created before they
existed.

---

## 1 · Theme and accent — the short answer

| setting | value | meaning |
|---|---|---|
| `Theme_Mode` | `dark` | dark by default |
| `Theme_AccentColor` | `#FF416C` | the brand red |

`#FF416C` is the lighter stop of the octopus gradient in
`Front-End/assets/icon.svg` (`#FF416C` → `#FF4B2B`) and the accent the marketing
site uses. Material 3 generates the entire colour scheme from this one seed, so
it is the only value that has to be right.

It must stay in step in **three** places, or the app disagrees with itself
depending on whether settings have synced yet:

| where | constant |
|---|---|
| `Back-End/.../CompanyDefaultsSeeder.cs` | `("Theme_AccentColor", "#FF416C")` |
| `Front-End/lib/app_settings/app_settings_model.dart` | `kSettingDefaults[themeAccentColor]` |
| `Front-End/lib/core/app_theme.dart` | `kBrandAccent` |

> Before 2026-09-04 these were `#10B981` (emerald), `#FF5733` (coral) and
> `#FF416C` — three sources, three colours, only one of them the logo. The coral
> is what made the app look **brown**: Material desaturates it heavily when
> seeding a dark scheme.

```sql
-- What a given company is actually using right now
SELECT Name, Value
FROM   dbo.ApplicationProperty
WHERE  CompanyId = @CompanyId AND Name IN ('Theme_Mode','Theme_AccentColor');
```

---

## 2 · Rows created

### Warehouse
```sql
INSERT INTO dbo.Warehouse (CompanyId, Name) VALUES (@CompanyId, N'Main Warehouse');
```
Only when the company has none.

### Walk-in customer and default supplier
```sql
-- C000: the customer a cash sale is booked against when nobody is identified
INSERT INTO dbo.Customer (CompanyId, Code, Name, IsCustomer, IsSupplier, IsEnabled, DueDatePeriod, IsTaxExempt)
VALUES (@CompanyId, N'C000', N'Walk-in Customer', 1, 0, 1, 0, 0);

-- S000: the counterparty for purchases before a real supplier exists
INSERT INTO dbo.Customer (CompanyId, Code, Name, IsCustomer, IsSupplier, IsEnabled, DueDatePeriod, IsTaxExempt)
VALUES (@CompanyId, N'S000', N'Default Supplier', 0, 1, 1, 0, 0);
```

### Payment types
Seeded only when the company has none at all — so removing "Credit" does not
bring it back on the next startup.

| Name | Ordinal | Customer required | Change allowed | Opens drawer | Marks paid |
|---|---|---|---|---|---|
| `Espèces` (cash) | 1 | no | **yes** | yes | yes |
| `Credit` | 2 | **yes** | no | yes | **no** |

> `Credit` does not mark the sale paid — that is what makes it a receivable.
> There is no `IsCash` flag anywhere; "is this cash?" is inferred from
> `IsChangeAllowed`, which is why `PosSession.CashPaymentTypeIds` exists as an
> override.

### Printer
```sql
INSERT INTO dbo.PosPrinterSettings (CompanyId, PrinterName, PaperWidth)
VALUES (@CompanyId, N'Microsoft Print to PDF', 48);   -- 48 chars ~ 80mm
```

### Barcode nomenclature
Four rules, mirroring Odoo's defaults. **Order matters** — the catch-all `Unit`
rule must stay last or it swallows every scale label.

| Sequence | Name | Type | Encoding | Pattern |
|---|---|---|---|---|
| 10 | Price Barcodes 2 Decimals | Priced | EAN-13 | `25.....{NNNDD}` |
| 20 | Weight Barcodes 3 Decimals | Weighted | EAN-13 | `22.....{NNDDD}` |
| 30 | Discount Barcodes | Discounted | Any | `22{NN}` |
| 40 | Product Barcodes | Unit | Any | `.*` |

---

## 3 · Security keys

45 keys, all seeded at **Level 0 (open to everyone)** so the company is usable
the moment it is created. An admin raises them to Level 1 (Admin) afterwards.
The domain permits only 0 or 1.

```sql
INSERT INTO dbo.SecurityKey (CompanyId, Name, Level) VALUES (@CompanyId, N'<key>', 0);
```

| # | Key |
|---|---|
| 1 | `Management` |
| 2 | `Settings` |
| 3 | `BusinessDay.Close` |
| 4 | `UserProfile` |
| 5 | `ShiftManagement` |
| 6 | `CashMovement` |
| 7 | `FloorPlans.Design` |
| 8 | `FloorPlans.View` |
| 9 | `Bookings` |
| 10 | `Bookings.History` |
| 11 | `Order.All` |
| 12 | `Order.Void` |
| 13 | `Order.Item.Void` |
| 14 | `Order.Estimate` |
| 15 | `Order.Estimate.Clear` |
| 16 | `Order.Transfer` |
| 17 | `Payment.Discount` |
| 18 | `Invoices.Delete` |
| 19 | `Refund` |
| 20 | `Payment.TaxOverride` |
| 21 | `SalesHistory` |
| 22 | `SalesHistory.Receipt` |
| 23 | `CreditPayments` |
| 24 | `StartingCash` |
| 25 | `CashDrawer.Open` |
| 26 | `Stock.Control.NegativeQuantity` |
| 27 | `Management.Dashboard` |
| 28 | `Management.Documents` |
| 29 | `Management.Products` |
| 30 | `Management.ProductGroups` |
| 31 | `Management.Stock` |
| 32 | `Management.Warehouses` |
| 33 | `Management.Reporting` |
| 34 | `Management.Customers` |
| 35 | `Management.Promotions` |
| 36 | `Management.Security` |
| 37 | `Management.PaymentTypes` |
| 38 | `Management.Countries` |
| 39 | `Management.Currencies` |
| 40 | `Management.TaxRates` |
| 41 | `Management.Company` |
| 42 | `Management.VoidReasons` |
| 43 | `Management.Stock.QuickInventory` |
| 44 | `Management.Stock.ShowCostPrices` |
| 45 | `Management.LoyaltyCards` |

---

## 4 · Application settings

**95** rows in `dbo.ApplicationProperty`, one per key:

```sql
INSERT INTO dbo.ApplicationProperty (CompanyId, Name, Value)
VALUES (@CompanyId, N'<name>', N'<value>');
```

Three of the 95 hold JSON and are listed separately below the table, because a
table cell cannot show them legibly.

| Setting | Default |
|---|---|
| `CurrencySymbol` | `DH` |
| `PosSession.MaxCashDifference` | `10` |
| `PosSession.CashPaymentTypeIds` | `*(empty)*` |
| `PosSession.RequireOpenSession` | `true` |
| `Application.Api.BaseUrl` | `https://api.octopus-pos.com/api` |
| `Database.Backup.Version` | `v2` |
| `Theme_Mode` | `dark` |
| `Theme_AccentColor` | `#FF416C` |
| `Menu_Grid_Cols` | `4` |
| `Menu_Grid_Rows` | `4` |
| `Application.Language` | `en` |
| `Feature_FloorPlan_Enabled` | `false` |
| `Feature_Booking_Enabled` | `false` |
| `Feature_ServiceType_Enabled` | `true` |
| `Feature_ServiceStatus_Enabled` | `true` |
| `Application.TimezoneMode` | `Auto` |
| `Application.Timezone` | `Africa/Casablanca` |
| `Application.DateFormat` | `dd/MM/yyyy` |
| `General.TaxIncludedByDefault` | `true` |
| `General.DefaultTaxRateIds` | `*(empty)*` |
| `Feature.TablesButtonLabel` | `TABLES` |
| `Order.AllowTablelessOrders` | `false` |
| `Order.AllowWalkInTableOrders` | `true` |
| `Print.CashDrawer.Enabled` | `false` |
| `Print.PrinterType` | `Windows Printer` |
| `Invoice.Columns.Discount` | `true` |
| `Receipt.LogoFullWidth` | `false` |
| `Receipt.PrinterName` | `Microsoft Print to PDF` |
| `Kitchen.PrinterName` | `Microsoft Print to PDF` |
| `Receipt.FontSize` | `100` |
| `Receipt.Footer` | ` ` |
| `Receipt.Header` | ` ` |
| `Kitchen.PaperSize` | `80mm` |
| `Void.RequireReason` | `true` |
| `App.WritingDirection` | `LTR` |
| `ButtonBar.ShowSearch` | `true` |
| `ButtonBar.ShowTransfer` | `true` |
| `ButtonBar.ShowCustomer` | `true` |
| `ButtonBar.ShowDiscount` | `true` |
| `ButtonBar.ShowRefund` | `true` |
| `ButtonBar.ShowCashDrawer` | `true` |
| `App.ShowCashInOnStart` | `false` |
| `App.SelectBusinessDayOnStart` | `true` |
| `App.MessagePosition` | `Top` |
| `App.MessageDuration` | `5` |
| `App.EnableVirtualKeyboard` | `true` |
| `ButtonBar.ShowWarehouse` | `true` |
| `ButtonBar.ShowBooking` | `true` |
| `ButtonBar.ShowTables` | `true` |
| `ButtonBar.ShowTax` | `true` |
| `ButtonBar.ShowKitchen` | `true` |
| `App.EnableSounds` | `true` |
| `Menu.DefaultSearch` | `All fields` |
| `Menu.ShowSearchOptions` | `true` |
| `Order.DefaultDiscountType` | `Fixed` |
| `Order.SeparateRowForEachItem` | `true` |
| `Order.PreventSaleBelowCostPrice` | `true` |
| `Order.PreventNegativeInventory` | `true` |
| `App.SingleUser` | `true` |
| `Order.DisplayReceiptPrintDialog` | `true` |
| `Order.DefaultDueDateDays` | `2` |
| `Receipt.MergeItems` | `false` |
| `Order.SingleItemDiscountAllowed` | `true` |
| `Order.ShortcutKeysPaymentConfirmation` | `false` |
| `Void.TrackUnconfirmed` | `false` |
| `Feature.ServiceType.SelectionEnabled` | `false` |
| `Feature.ServiceType.RequestAutomatically` | `false` |
| `Feature.ServiceType.Default` | `Dine-in` |
| `Receipt.PrintLargeOrderNumber` | `true` |
| `Order.ResetNumberOnDayClose` | `true` |
| `Order.ShowItemsOnPaymentForm` | `true` |
| `Order.NumberOfPaymentTypeRows` | `1` |
| `Feature.FloorPlan.ShowAllOccupied` | `true` |
| `Kitchen.DisplayIps` | `*(empty)*` |
| `Products.ShowImages` | `true` |
| `Products.AllowNegativePrice` | `false` |
| `Products.DisplayAndPrintTaxIncluded` | `true` |
| `Products.DiscountApplyRule` | `After tax` |
| `Products.Sorting` | `Code` |
| `Products.CostPriceBasedMarkup` | `true` |
| `Products.AutoUpdateCostPrice` | `false` |
| `Products.EnableMovingAveragePrice` | `true` |
| `Scale.Barcode.Enabled` | `true` |
| `Scale.Barcode.Prefix` | `21` |
| `Scale.Barcode.CodeLength` | `5` |
| `Scale.Barcode.DecimalPlaces` | `3` |
| `Scale.Barcode.TrimZeros` | `true` |
| `Scale.Barcode.PrintsPrice` | `false` |
| `Database.BackupPath` | `*(empty)*` |
| `Database.AutoBackup` | `true` |
| `Database.Backup.OnStart` | `true` |
| `Database.Backup.OnClose` | `true` |

### The three JSON settings

`Pos.CustomServiceTypes` — the order types on the sales floor. `prefix` is what
the order number is built from, so changing one renumbers new orders.

```json
[{"id":0,"name":"Dine-In","prefix":"TALABIA"},
 {"id":1,"name":"Takeaway","prefix":"TAKEAWAY"},
 {"id":2,"name":"Delivery","prefix":"DELIVERY"}]
```

`Pos.CustomServiceStatuses` — kitchen states. `colorValue` is a signed 32-bit
ARGB int as Flutter's `Color.value`, not a hex string.

```json
[{"id":1,"name":"standby","colorValue":4280391411},
 {"id":2,"name":"IN-Kitchen","colorValue":4294940672},
 {"id":3,"name":"COOKED","colorValue":4283215696}]
```

`Pos.BookingSettings`

```json
{"resourceMode":"table","defaultDurationMinutes":90,
 "timeSnappingMinutes":15,"allowPastBookings":false}
```

---

## 5 · Global data — seeded once per DATABASE, not per company

`GlobalDefaultsSeeder.SeedAsync` runs at API startup and is **not**
company-scoped. These tables have no `CompanyId`, which is why a company delete
can never reach them.

**Document categories:** Expenses (1), Sales (2), Inventory (3), Loss (4)

**Document types:** Purchase `100`, Sales `200`, Inventory Count `300`,
Refund `220`, Stock Return `120`, Loss And Damage `400`, Proforma `230`

**Currency:** `MAD` — Moroccan Dirham

---

## 6 · Inspecting a real company

```sql
DECLARE @CompanyId INT = 25;

SELECT Name, Value FROM dbo.ApplicationProperty WHERE CompanyId = @CompanyId ORDER BY Name;
SELECT Name, Level FROM dbo.SecurityKey        WHERE CompanyId = @CompanyId ORDER BY Name;
SELECT Code, Name, IsCustomer, IsSupplier      FROM dbo.Customer WHERE CompanyId = @CompanyId AND Code IN ('C000','S000');
SELECT Name, Ordinal, IsChangeAllowed, MarkAsPaid FROM dbo.PaymentType WHERE CompanyId = @CompanyId ORDER BY Ordinal;
SELECT Sequence, Name, Type, Encoding, Pattern FROM dbo.BarcodeRule WHERE CompanyId = @CompanyId ORDER BY Sequence;
SELECT Name FROM dbo.Warehouse                 WHERE CompanyId = @CompanyId;

-- Settings this company has that the seeder does NOT define (drifted or hand-added)
-- and settings the seeder defines that this company is missing, are the two
-- things worth checking when a terminal behaves unlike a fresh install.
```
