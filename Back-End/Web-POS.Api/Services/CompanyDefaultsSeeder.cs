using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    /// <summary>
    /// Writes the baseline data every brand-new company needs to start up:
    /// a default warehouse, the "C000" walk-in customer, and the full set of
    /// ApplicationProperty settings. Runs automatically inside company creation.
    /// </summary>
    public static class CompanyDefaultsSeeder
    {
        public const string WalkInCustomerCode = "C000";
        public const string SupplierCode = "S000";
        public const string DefaultWarehouseName = "Main Warehouse";

        /// <summary>
        /// Idempotent: only adds what's missing, so it can be re-run safely and
        /// never collides with pre-existing rows for the company.
        /// </summary>
        public static async Task SeedAsync(AppDbContext db, int companyId)
        {
            // Default warehouse (only if the company has none).
            if (!await db.Warehouses.AnyAsync(w => w.CompanyId == companyId))
                db.Warehouses.Add(Warehouse.Create(companyId, DefaultWarehouseName));

            // Walk-in customer (code C000) — only if not already present.
            if (!await db.Customers.AnyAsync(c => c.CompanyId == companyId && c.Code == WalkInCustomerCode))
            {
                db.Customers.Add(Customer.Create(
                    companyId,
                    WalkInCustomerCode,        // code
                    "Walk-in Customer",        // name
                    null,                      // taxNumber
                    null,                      // address
                    null,                      // postalCode
                    null,                      // city
                    null,                      // countryId
                    DateTime.UtcNow,           // dateCreated
                    null,                      // email
                    null,                      // phoneNumber
                    true,                      // isEnabled
                    true,                      // isCustomer
                    false,                     // isSupplier
                    0,                         // dueDatePeriod
                    null, null, null, null, null, // street/building/etc.
                    false));                   // isTaxExempt
            }

            // Default supplier (code S000) — only if not already present.
            if (!await db.Customers.AnyAsync(c => c.CompanyId == companyId && c.Code == SupplierCode))
            {
                db.Customers.Add(Customer.Create(
                    companyId,
                    SupplierCode,              // code
                    "Default Supplier",        // name
                    null,                      // taxNumber
                    null,                      // address
                    null,                      // postalCode
                    null,                      // city
                    null,                      // countryId
                    DateTime.UtcNow,           // dateCreated
                    null,                      // email
                    null,                      // phoneNumber
                    true,                      // isEnabled
                    false,                     // isCustomer
                    true,                      // isSupplier
                    0,                         // dueDatePeriod
                    null, null, null, null, null, // street/building/etc.
                    false));                   // isTaxExempt
            }

            // Default payment types (only if the company has none yet).
            if (!await db.PaymentTypes.AnyAsync(p => p.CompanyId == companyId))
            {
                // Cash (Espèces)
                db.PaymentTypes.Add(PaymentType.Create(
                    companyId, "Espèces", "",
                    iscustomerrequired: false, isfiscal: true, issliprequired: false,
                    ischnageallowed: true, ordinal: 1, isenabled: true, isquickpayment: true,
                    opencashdrawer: true, shortcutkey: null, markaspaid: true));

                // Credit
                db.PaymentTypes.Add(PaymentType.Create(
                    companyId, "Credit", "",
                    iscustomerrequired: true, isfiscal: true, issliprequired: false,
                    ischnageallowed: false, ordinal: 2, isenabled: true, isquickpayment: true,
                    opencashdrawer: true, shortcutkey: null, markaspaid: false));
            }

            // Application settings — add only keys the company doesn't already have.
            var existing = await db.ApplicationProperties
                .Where(p => p.CompanyId == companyId)
                .Select(p => p.Name)
                .ToListAsync();
            var have = new HashSet<string>(existing.Where(n => n != null)!, StringComparer.OrdinalIgnoreCase);

            foreach (var (name, value) in DefaultProperties)
                if (!have.Contains(name))
                    db.ApplicationProperties.Add(ApplicationProperty.Create(companyId, name, value));

            // Security keys — add only keys the company doesn't already have, so
            // keys introduced in a later app version reach companies that were
            // seeded before the key existed (rather than the old all-or-nothing
            // check, which silently skipped every new key once any key existed).
            // Seeded at Level 0 (open to everyone) so the company is usable
            // immediately; the admin raises them to 1 (Admin) later. The domain
            // only allows levels 0 or 1.
            var existingKeys = await db.SecurityKeys
                .Where(s => s.CompanyId == companyId)
                .Select(s => s.Name)
                .ToListAsync();
            var haveKeys = new HashSet<string>(existingKeys.Where(n => n != null)!, StringComparer.OrdinalIgnoreCase);

            foreach (var keyName in DefaultSecurityKeys)
                if (!haveKeys.Contains(keyName))
                    db.SecurityKeys.Add(SecurityKey.Create(companyId, keyName, 0));

            // Standalone printer config (80mm ≈ 48 char width).
            if (!await db.PosPrinterSettings.AnyAsync(p => p.CompanyId == companyId))
            {
                var ps = PosPrinterSettings.Create("Microsoft Print to PDF", paperWidth: 48);
                ps.CompanyId = companyId;
                db.PosPrinterSettings.Add(ps);
            }

            // Barcode nomenclature (the four default rules).
            await BarcodeRuleSeeder.SeedAsync(db, companyId);

            await db.SaveChangesAsync();
        }

        /// <summary>
        /// Ensures every existing company has the full <see cref="DefaultSecurityKeys"/>
        /// set. Keys introduced in an app update are added at Level 0 (open) for
        /// companies created before the key existed; pre-existing keys — and any
        /// admin-customised levels — are left untouched. Idempotent and non-fatal,
        /// so it's safe to run on every startup. This is what makes new screen/action
        /// keys (e.g. CashMovement, ShiftManagement) reach already-provisioned tenants.
        /// </summary>
        public static async Task BackfillSecurityKeysAsync(AppDbContext db)
        {
            var companyIds = await db.Companies.Select(c => c.Id).ToListAsync();
            if (companyIds.Count == 0) return;

            // ONE query for every company's existing key names, instead of one query
            // per company. This runs on every startup, so the previous N+1 made boot
            // time scale linearly with tenant count — noticeable on a SaaS control
            // plane with many companies. Projected to (CompanyId, Name) so the
            // payload stays small regardless of how many keys exist.
            var existingByCompany = (await db.SecurityKeys
                    .AsNoTracking()
                    .Select(s => new { s.CompanyId, s.Name })
                    .ToListAsync())
                .GroupBy(s => s.CompanyId)
                .ToDictionary(
                    g => g.Key,
                    g => new HashSet<string>(
                        g.Select(x => x.Name).Where(n => n != null)!,
                        StringComparer.OrdinalIgnoreCase));

            var added = false;
            foreach (var companyId in companyIds)
            {
                if (!existingByCompany.TryGetValue(companyId, out var have))
                    have = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                foreach (var keyName in DefaultSecurityKeys)
                {
                    if (!have.Contains(keyName))
                    {
                        db.SecurityKeys.Add(SecurityKey.Create(companyId, keyName, 0));
                        added = true;
                    }
                }
            }

            // Skip the round-trip entirely on the common startup where nothing is
            // missing (every boot after the first following an app update).
            if (added)
                await db.SaveChangesAsync();
        }

        /// <summary>
        /// ApplicationProperty keys that used to be seeded and have since been
        /// fully retired from the app (no frontend constant reads them, no
        /// backend code writes them). <see cref="SeedAsync"/> only ever ADDS a
        /// missing key, so removing one from <see cref="DefaultProperties"/>
        /// never deletes the row for a company that was seeded before the
        /// removal — that row is what <see cref="RemoveObsoletePropertiesAsync"/>
        /// sweeps up. Add a name here whenever a setting is retired; never
        /// reuse a retired name for something new without renaming it first.
        /// </summary>
        public static readonly string[] ObsoleteProperties =
        {
            // Removed from the app; stale rows survived from companies seeded
            // before the removal (POS_Manual_tests_NOTES.txt, audited 2026-08-30).
            "App.IndustryMode",
        };

        /// <summary>
        /// Deletes any lingering rows for <see cref="ObsoleteProperties"/>, across
        /// every company. Idempotent and non-fatal — safe to run on every startup
        /// (mirrors <see cref="BackfillSecurityKeysAsync"/>), and a no-op once a
        /// database has been swept once.
        /// </summary>
        public static async Task RemoveObsoletePropertiesAsync(AppDbContext db)
        {
            var stale = await db.ApplicationProperties
                .Where(p => p.Name != null && ObsoleteProperties.Contains(p.Name))
                .ToListAsync();

            if (stale.Count == 0) return;

            db.ApplicationProperties.RemoveRange(stale);
            await db.SaveChangesAsync();
        }

        /// <summary>
        /// Baseline settings every company starts with. NOTE: a few values are
        /// environment/user-specific (Application.User.Email, Database.BackupPath,
        /// Kitchen.DisplayIps, Application.Api.BaseUrl) — adjust as needed.
        /// </summary>
        public static readonly (string Name, string Value)[] DefaultProperties =
        {
            ("CurrencySymbol", "DH"),
            // POS session — the cash difference a cashier may close through on
            // their own. Above it, closing needs manager authorisation. Per
            // company and editable, so a busy shop can loosen it without a
            // code change; "0" means every discrepancy needs a manager.
            ("PosSession.MaxCashDifference", "10"),
            // Optional override: comma-separated PaymentType ids that come out
            // of the cash drawer. Empty = infer from IsChangeAllowed, because
            // there is no IsCash flag and OpenCashDrawer is true for Credit too.
            ("PosSession.CashPaymentTypeIds", ""),
            // Master switch for the no-sale-without-a-session rule. Also the
            // recovery path: if session state is ever wrong on a real till,
            // turning this off restores trading immediately.
            ("PosSession.RequireOpenSession", "true"),
            ("Application.Api.BaseUrl", "https://api.futur3.com/api"),
            ("Application.User.Email", ""),
            ("Database.Backup.Version", "v2"),
            ("Theme_Mode", "dark"),
            ("Theme_AccentColor", "#10B981"),
            ("Menu_Grid_Cols", "4"),
            ("Menu_Grid_Rows", "4"),
            ("Application.Language", "en"),
            ("Feature_FloorPlan_Enabled", "false"),
            ("Feature_Booking_Enabled", "false"),
            ("Feature_ServiceType_Enabled", "true"),
            ("Feature_ServiceStatus_Enabled", "true"),
            ("Application.TimezoneMode", "Auto"),
            ("Application.Timezone", "Africa/Casablanca"),
            ("Application.DateFormat", "dd/MM/yyyy"),
            // "true" to match kSettingDefaults on the client. Every product
            // ever created in this app has been tax-inclusive (the editor
            // hardcoded it), so seeding "false" would silently flip pricing to
            // tax-exclusive for existing installs the first time they synced.
            ("General.TaxIncludedByDefault", "true"),
            // Companion of the switch above — the tax-inclusive setting cannot
            // be turned on without at least one rate. Seeded empty because tax
            // rate IDs are per-company; the client's picker fills it in.
            ("General.DefaultTaxRateIds", ""),
            ("Pos.CustomServiceTypes", @"[{""id"":0,""name"":""Dine-In"",""prefix"":""TALABIA""},{""id"":1,""name"":""Takeaway"",""prefix"":""TAKEAWAY""},{""id"":2,""name"":""Delivery"",""prefix"":""DELIVERY""}]"),
            ("Pos.CustomServiceStatuses", @"[{""id"":1,""name"":""standby"",""colorValue"":4280391411},{""id"":2,""name"":""IN-Kitchen"",""colorValue"":4294940672},{""id"":3,""name"":""COOKED"",""colorValue"":4283215696}]"),
            ("Feature.TablesButtonLabel", "TABLES"),
            // Match kSettingDefaults in the client's app_settings_model.dart:
            // a dine-in order still needs a table, and a free table can still be
            // rung up without a booking.
            ("Order.AllowTablelessOrders", "false"),
            ("Order.AllowWalkInTableOrders", "true"),
            ("Pos.BookingSettings", @"{""resourceMode"":""table"",""defaultDurationMinutes"":90,""timeSnappingMinutes"":15,""allowPastBookings"":false}"),
            ("Print.CashDrawer.Enabled", "false"),
            ("Print.PrinterType", "Windows Printer"),
            ("Invoice.Columns.Discount", "true"),
            ("Receipt.LogoFullWidth", "false"),
            ("Receipt.PrinterName", "Microsoft Print to PDF"),
            ("Kitchen.PrinterName", "Microsoft Print to PDF"),
            ("Receipt.FontSize", "100"),
            ("Receipt.Footer", " "),
            ("Receipt.Header", " "),
            ("Kitchen.PaperSize", "80mm"),
            ("Void.RequireReason", "true"),
            ("App.WritingDirection", "LTR"),
            ("ButtonBar.ShowSearch", "true"),
            ("ButtonBar.ShowTransfer", "true"),
            ("ButtonBar.ShowCustomer", "true"),
            ("ButtonBar.ShowDiscount", "true"),
            ("ButtonBar.ShowComment", "true"),
            ("ButtonBar.ShowRefund", "true"),
            ("ButtonBar.ShowCashDrawer", "true"),
            ("App.ShowCashInOnStart", "false"),
            ("App.SelectBusinessDayOnStart", "true"),
            ("App.MessagePosition", "Top"),
            ("App.MessageDuration", "5"),
            ("App.EnableVirtualKeyboard", "true"),
            ("ButtonBar.ShowWarehouse", "true"),
            ("ButtonBar.ShowBooking", "true"),
            ("ButtonBar.ShowTables", "true"),
            ("ButtonBar.ShowTax", "true"),
            ("ButtonBar.ShowKitchen", "true"),
            ("App.EnableSounds", "true"),
            ("Menu.DefaultSearch", "All fields"),
            ("Menu.ShowSearchOptions", "true"),
            ("Order.DefaultDiscountType", "Fixed"),
            ("Order.SeparateRowForEachItem", "true"),
            ("Order.PreventSaleBelowCostPrice", "true"),
            ("Order.PreventNegativeInventory", "true"),
            ("App.SingleUser", "true"),
            ("Order.DisplayReceiptPrintDialog", "true"),
            ("Order.DefaultDueDateDays", "2"),
            ("Receipt.MergeItems", "false"),
            ("Order.SingleItemDiscountAllowed", "true"),
            ("Order.ShortcutKeysPaymentConfirmation", "false"),
            ("Void.TrackUnconfirmed", "false"),
            ("Feature.ServiceType.SelectionEnabled", "false"),
            ("Feature.ServiceType.RequestAutomatically", "false"),
            ("Feature.ServiceType.Default", "Dine-in"),
            ("Receipt.PrintLargeOrderNumber", "true"),
            ("Order.ResetNumberOnDayClose", "true"),
            ("Order.ShowItemsOnPaymentForm", "true"),
            ("Order.NumberOfPaymentTypeRows", "1"),
            ("Feature.FloorPlan.ShowAllOccupied", "true"),
            ("Kitchen.DisplayIps", ""),
            ("Products.ShowImages", "true"),
            ("Products.AllowNegativePrice", "false"),
            ("Products.DisplayAndPrintTaxIncluded", "true"),
            ("Products.DiscountApplyRule", "After tax"),
            ("Products.Sorting", "Code"),
            ("Products.CostPriceBasedMarkup", "true"),
            ("Products.AutoUpdateCostPrice", "false"),
            ("Products.EnableMovingAveragePrice", "true"),
            // DEPRECATED — superseded by the BarcodeRule table. Kept so
            // BarcodeRuleSeeder.BackfillAsync can still translate an existing
            // company's scale format into a rule. Nothing reads them at runtime.
            ("Scale.Barcode.Enabled", "true"),
            ("Scale.Barcode.Prefix", "21"),
            ("Scale.Barcode.CodeLength", "5"),
            ("Scale.Barcode.DecimalPlaces", "3"),
            ("Scale.Barcode.TrimZeros", "true"),
            ("Scale.Barcode.PrintsPrice", "false"),
            ("Database.BackupPath", ""),
            ("Database.AutoBackup", "true"),
            ("Database.Backup.OnStart", "true"),
            ("Database.Backup.OnClose", "true"),
        };

        /// <summary>
        /// Security keys the POS app checks across its screens. Seeded at Level 0
        /// (open) for a new company. (Management.LoyaltyCards was added — the app
        /// checks it but it was missing from the supplied list.)
        /// </summary>
        public static readonly string[] DefaultSecurityKeys =
        {
            // ── General / sidebar screen access ──────────────────────────────
            "Management",
            "Settings",
            "BusinessDay.Close",
            "UserProfile",
            "ShiftManagement",      // Shift Management screen (sidebar)
            "CashMovement",         // Cash In / Out screen (sidebar)
            "FloorPlans.Design",
            "FloorPlans.View",      // Floor Plan / Tables screen access
            "Bookings",             // Bookings / calendar screen
            "Bookings.History",     // Booking history screen
            // ── Sales floor actions ──────────────────────────────────────────
            "Order.All",
            "Order.Void",
            "Order.Item.Void",
            "Order.Estimate",
            "Order.Estimate.Clear",
            "Order.Transfer",
            "Payment.Discount",
            "Invoices.Delete",
            "Refund",
            "Payment.TaxOverride",
            "SalesHistory",
            "SalesHistory.Receipt",
            "CreditPayments",
            "StartingCash",
            "CashDrawer.Open",
            "Stock.Control.NegativeQuantity",
            // ── Management portal screens ────────────────────────────────────
            "Management.Dashboard",
            "Management.Documents",
            "Management.Products",
            "Management.ProductGroups",  // Product Groups tab
            "Management.Stock",
            "Management.Warehouses",      // Warehouses screen (from Stock)
            "Management.Reporting",
            "Management.Customers",
            "Management.Promotions",
            "Management.Security",
            "Management.PaymentTypes",
            "Management.Countries",
            "Management.Currencies",      // Currencies screen
            "Management.TaxRates",
            "Management.Company",
            "Management.VoidReasons",     // Void reasons tab
            "Management.Stock.QuickInventory",
            "Management.Stock.ShowCostPrices",
            "Management.LoyaltyCards",
        };
    }
}
