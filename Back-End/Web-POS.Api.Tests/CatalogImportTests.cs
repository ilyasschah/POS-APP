using Api.Commands.ProductCommands.Import;
using Api.Commands.ProductGroupCommands.Import;
using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using Api.Queries.ProductGroupsQuery;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The catalogue import and export: products, product groups, and the group
/// export's ordering.
///
/// <para>What these pin, found while checking the feature on 2026-09-10:</para>
/// <list type="bullet">
///   <item>one bad row used to sink every row after it (its entity stayed tracked
///     and rode along with each later save), so rows are validated up front and
///     each one is its own unit of work;</item>
///   <item>a barcode already on another product, an unknown tax rate or supplier
///     used to vanish silently — they are warnings now;</item>
///   <item>an XML export's group hierarchy was flattened on import — a group path
///     now rebuilds it;</item>
///   <item>a merge that did not repeat a stock-control column wiped it;</item>
///   <item>product groups had no import at all.</item>
/// </list>
///
/// <para>SQLite does not enforce column lengths the way SQL Server does, which is
/// exactly why over-long cells are checked before any save rather than left to
/// the database: here they fail the validation, there they would have thrown.</para>
/// </summary>
public class CatalogImportTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;
    private readonly int _company;

    public CatalogImportTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _options = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_connection).Options;

        using var db = new AppDbContext(_options);
        db.Database.EnsureCreated();
        db.Countries.Add(new Country { Id = 1, Name = "Morocco", Code = "MA" });
        db.SaveChanges();
        var company = Company.Create("Shop", 1, null, null, null, null, null, null,
            null, null, null, null, null, null, null, null);
        db.Companies.Add(company);
        db.SaveChanges();
        _company = company.Id;
        db.Warehouses.Add(Warehouse.Create(_company, "Main"));
        db.SaveChanges();
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private AppDbContext Db() => new(_options);

    private async Task<ImportProductsResult> ImportProducts(
        bool merge, bool skip, params ImportProductRow[] rows)
    {
        await using var db = Db();
        return await new ImportProductsCommandHandler(db).Handle(
            new ImportProductsCommand(new ImportProductsRequest
            {
                CompanyId = _company,
                MergeDuplicates = merge,
                SkipDuplicates = skip,
                DocumentType = "none",
                Rows = rows.ToList(),
            }), default);
    }

    private Task<ImportProductsResult> ImportProducts(params ImportProductRow[] rows) =>
        ImportProducts(merge: false, skip: false, rows);

    /// <summary>An import that writes an Inventory Count, merging into the
    /// products already there — the shape of a stock-take spreadsheet.</summary>
    private async Task<ImportProductsResult> ImportCount(params ImportProductRow[] rows)
    {
        await using var db = Db();
        return await new ImportProductsCommandHandler(db).Handle(
            new ImportProductsCommand(new ImportProductsRequest
            {
                CompanyId = _company,
                MergeDuplicates = true,
                SkipDuplicates = false,
                DocumentType = "inventoryCount",
                Rows = rows.ToList(),
            }), default);
    }

    /// <summary>
    /// A count document points at a user and at its document type. In
    /// production the seeder provides the type; nothing does in here.
    /// </summary>
    private void SeedCountPrerequisites()
    {
        using var db = Db();
        db.DocumentCategories.Add(new DocumentCategory
        {
            Id = DocumentCategoryConstants.Inventory,
            Name = "Inventory",
        });
        var countType = DocumentType.Create(
            "Inventory Count", DocumentTypeConstants.InventoryCountCode,
            DocumentCategoryConstants.Inventory, stockDirection: 1);
        countType.Id = DocumentTypeConstants.InventoryCount;
        db.DocumentTypes.Add(countType);
        db.Users.Add(User.Create(_company, "Stock", "Taker", "counter", "hash", 1, true, null));
        db.SaveChanges();
    }

    private async Task<ImportProductGroupsResult> ImportGroups(
        bool merge, bool skip, params ImportProductGroupRow[] rows)
    {
        await using var db = Db();
        return await new ImportProductGroupsCommandHandler(db).Handle(
            new ImportProductGroupsCommand(new ImportProductGroupsRequest
            {
                CompanyId = _company,
                MergeDuplicates = merge,
                SkipDuplicates = skip,
                Rows = rows.ToList(),
            }), default);
    }

    private Task<ImportProductGroupsResult> ImportGroups(params ImportProductGroupRow[] rows) =>
        ImportGroups(merge: false, skip: false, rows);

    private static ImportProductGroupRow G(string name, string? parent = null, string? color = null, int? rank = null) =>
        new() { Name = name, ParentGroupName = parent, Color = color, Rank = rank };

    private Dictionary<string, string?> ParentByName()
    {
        using var db = Db();
        var all = db.ProductGroups.AsNoTracking().Where(g => g.CompanyId == _company).ToList();
        var byId = all.ToDictionary(g => g.Id);
        return all.ToDictionary(
            g => g.Name,
            g => g.ParentGroupId is int p && byId.TryGetValue(p, out var parent) ? parent.Name : null);
    }

    private int AddGroup(string name, int? parentId = null)
    {
        using var db = Db();
        var g = ProductGroup.Create(name, parentId, "Transparent", null, 0, _company);
        db.ProductGroups.Add(g);
        db.SaveChanges();
        return g.Id;
    }

    // ═══ Products ═══════════════════════════════════════════════════════════

    [Fact]
    public async Task A_group_path_is_rebuilt_as_a_real_hierarchy()
    {
        var result = await ImportProducts(new ImportProductRow
        {
            Name = "Mint tea",
            ProductGroupPath = ["Drinks", "Hot", "Tea"],
        });

        Assert.Equal(1, result.Created);
        var parents = ParentByName();
        Assert.Null(parents["Drinks"]);
        Assert.Equal("Drinks", parents["Hot"]);
        Assert.Equal("Hot", parents["Tea"]);

        using var db = Db();
        var product = db.Products.Include(p => p.ProductGroup).Single(p => p.Name == "Mint tea");
        Assert.Equal("Tea", product.ProductGroup!.Name);
    }

    [Fact]
    public async Task An_existing_group_is_used_where_it_is_and_nothing_is_built_above_it()
    {
        // Names are unique per company, so "Tea" already IS the group. Building
        // the rest of the path would leave an empty "Drinks" lying about.
        AddGroup("Tea");

        await ImportProducts(new ImportProductRow { Name = "Green tea", ProductGroupPath = ["Drinks", "Tea"] });

        var parents = ParentByName();
        Assert.Single(parents);
        Assert.Null(parents["Tea"]);
    }

    [Fact]
    public async Task A_group_name_alone_still_works()
    {
        await ImportProducts(new ImportProductRow { Name = "Espresso", ProductGroupName = "Coffee" });

        Assert.Null(ParentByName()["Coffee"]);
    }

    [Fact]
    public async Task Every_barcode_on_the_row_is_attached()
    {
        await ImportProducts(new ImportProductRow
        {
            Name = "Water",
            Barcodes = ["111", "222"],
            Barcode = "333",
        });

        using var db = Db();
        var codes = db.Barcodes.Select(b => b.Value).OrderBy(v => v).ToList();
        Assert.Equal(["111", "222", "333"], codes);
    }

    [Fact]
    public async Task A_barcode_already_on_another_product_is_reported_not_stolen()
    {
        await ImportProducts(new ImportProductRow { Name = "Cola", Barcode = "555" });

        var result = await ImportProducts(new ImportProductRow { Name = "Fanta", Barcode = "555" });

        Assert.Equal(1, result.Created);
        Assert.Contains(result.Warnings, w => w.Contains("555"));
        using var db = Db();
        var owner = db.Barcodes.Include(b => b.Product).Single(b => b.Value == "555").Product!;
        Assert.Equal("Cola", owner.Name);
    }

    [Fact]
    public async Task An_unknown_tax_rate_is_reported_and_the_product_still_imports()
    {
        var result = await ImportProducts(new ImportProductRow { Name = "Juice", TaxRate = 7m });

        Assert.Equal(1, result.Created);
        Assert.Contains(result.Warnings, w => w.Contains("7"));
        using var db = Db();
        Assert.Empty(db.ProductsTaxes);
    }

    private int AddTax(string name, decimal rate, bool isFixed)
    {
        using var db = Db();
        var tax = Tax.Create(_company, name, rate, null, isFixed, istaxontotal: false, isenabled: true);
        db.Taxes.Add(tax);
        db.SaveChanges();
        return tax.Id;
    }

    [Fact]
    public async Task A_tax_rate_picks_the_tax_of_its_own_kind()
    {
        // The fixed one is older, so matching on the number alone attached it
        // to a row that meant 5%.
        var fixedTax = AddTax("Eco fee", 5m, isFixed: true);
        var percent = AddTax("VAT 5", 5m, isFixed: false);

        var result = await ImportProducts(
            new ImportProductRow { Name = "Juice", TaxRate = 5m },
            new ImportProductRow { Name = "Soda", TaxRate = 5m, TaxIsFixed = true });

        Assert.DoesNotContain(result.Warnings, w => w.Contains("tax"));
        using var db = Db();
        var ids = db.Products.ToDictionary(p => p.Name, p => p.Id);
        Assert.Equal(percent, db.ProductsTaxes.Single(pt => pt.ProductId == ids["Juice"]).TaxId);
        Assert.Equal(fixedTax, db.ProductsTaxes.Single(pt => pt.ProductId == ids["Soda"]).TaxId);
    }

    [Fact]
    public async Task A_fixed_rate_with_no_fixed_tax_is_reported_not_given_the_percentage()
    {
        AddTax("VAT 5", 5m, isFixed: false);

        var result = await ImportProducts(new ImportProductRow { Name = "Soda", TaxRate = 5m, TaxIsFixed = true });

        Assert.Equal(1, result.Created);
        Assert.Contains(result.Warnings, w => w.Contains("fixed"));
        using var db = Db();
        Assert.Empty(db.ProductsTaxes);
    }

    [Fact]
    public async Task An_unknown_supplier_is_reported()
    {
        var result = await ImportProducts(new ImportProductRow { Name = "Flour", SupplierName = "Nobody" });

        Assert.Equal(1, result.Created);
        Assert.Contains(result.Warnings, w => w.Contains("Nobody"));
    }

    [Fact]
    public async Task An_over_long_name_fails_only_its_own_row()
    {
        // The bug: one bad row used to take every row after it down with it.
        var result = await ImportProducts(
            new ImportProductRow { Name = "Before" },
            new ImportProductRow { Name = new string('x', 300) },
            new ImportProductRow { Name = "After" });

        Assert.Equal(2, result.Created);
        Assert.Single(result.Errors);
        using var db = Db();
        Assert.Equal(["After", "Before"], db.Products.Select(p => p.Name).OrderBy(n => n).ToList());
    }

    [Fact]
    public async Task An_over_long_SKU_or_unit_or_group_name_fails_only_its_own_row()
    {
        var result = await ImportProducts(
            new ImportProductRow { Name = "A", Code = new string('9', 101) },
            new ImportProductRow { Name = "B", MeasurementUnit = new string('u', 51) },
            new ImportProductRow { Name = "C", ProductGroupName = new string('g', 256) },
            new ImportProductRow { Name = "D" });

        Assert.Equal(1, result.Created);
        Assert.Equal(3, result.Errors.Count);
        using var db = Db();
        Assert.Empty(db.ProductGroups);
    }

    [Fact]
    public async Task Duplicates_are_skipped_unless_merging()
    {
        await ImportProducts(new ImportProductRow { Name = "Bread", Price = 2m });

        var skipped = await ImportProducts(new ImportProductRow { Name = "bread", Price = 9m });
        Assert.Equal(1, skipped.Skipped);

        var merged = await ImportProducts(merge: true, skip: false, new ImportProductRow { Name = "BREAD", Price = 3m });
        Assert.Equal(1, merged.Updated);

        using var db = Db();
        var bread = db.Products.Single();
        Assert.Equal(3m, bread.Price);
        Assert.Equal("Bread", bread.Name); // a merge never renames
    }

    [Fact]
    public async Task A_colour_is_imported_and_a_blank_one_keeps_the_tiles_colour()
    {
        // The export wrote no colour, so every re-import came back Transparent.
        await ImportProducts(new ImportProductRow { Name = "Mint tea", Color = "#FF4CAF50" });

        using (var db = Db())
            Assert.Equal("#FF4CAF50", db.Products.Single().Color);

        await ImportProducts(merge: true, skip: false, new ImportProductRow { Name = "Mint tea", Price = 4m });

        using (var db = Db())
            Assert.Equal("#FF4CAF50", db.Products.Single().Color);

        await ImportProducts(merge: true, skip: false, new ImportProductRow { Name = "Mint tea", Color = "#FF2196F3" });

        using (var db = Db())
            Assert.Equal("#FF2196F3", db.Products.Single().Color);
    }

    [Fact]
    public async Task A_product_with_no_colour_is_transparent()
    {
        await ImportProducts(new ImportProductRow { Name = "Plain", Color = "  " });

        using var db = Db();
        Assert.Equal("Transparent", db.Products.Single().Color);
    }

    [Fact]
    public async Task An_over_long_colour_fails_only_its_own_row()
    {
        var result = await ImportProducts(
            new ImportProductRow { Name = "Ok" },
            new ImportProductRow { Name = "Bad", Color = new string('c', 51) });

        Assert.Equal(1, result.Created);
        Assert.Single(result.Errors);
    }

    [Fact]
    public async Task Skip_wins_when_both_are_asked_for()
    {
        await ImportProducts(new ImportProductRow { Name = "Salt", Price = 1m });

        var result = await ImportProducts(merge: true, skip: true, new ImportProductRow { Name = "Salt", Price = 5m });

        Assert.Equal(1, result.Skipped);
        using var db = Db();
        Assert.Equal(1m, db.Products.Single().Price);
    }

    [Fact]
    public async Task The_same_product_twice_in_one_file_is_one_product()
    {
        var result = await ImportProducts(merge: true, skip: false,
            new ImportProductRow { Name = "Milk", Price = 1m },
            new ImportProductRow { Name = "Milk", Price = 2m });

        Assert.Equal(1, result.Created);
        Assert.Equal(1, result.Updated);
        using var db = Db();
        Assert.Equal(2m, db.Products.Single().Price);
    }

    [Fact]
    public async Task A_merge_that_leaves_out_a_stock_control_column_keeps_its_value()
    {
        // Merging used to pass the row's nulls straight into StockControl.Update.
        await ImportProducts(new ImportProductRow { Name = "Rice", ReorderPoint = 5m });

        await ImportProducts(merge: true, skip: false,
            new ImportProductRow { Name = "Rice", PreferredQuantity = 7m });

        using var db = Db();
        var sc = db.StockControls.Single();
        Assert.Equal(5m, sc.ReorderPoint);
        Assert.Equal(7m, sc.PreferredQuantity);
    }

    [Fact]
    public async Task Sell_by_weight_and_pack_size_survive_the_import()
    {
        await ImportProducts(
            new ImportProductRow { Name = "Saffron", MeasurementUnit = "g", IsToWeigh = true },
            new ImportProductRow { Name = "Cans", MeasurementUnit = "box", PackSize = 24m });

        using var db = Db();
        var saffron = db.Products.Single(p => p.Name == "Saffron");
        Assert.True(saffron.IsToWeigh);
        Assert.Equal(11, saffron.UomId);
        var cans = db.Products.Single(p => p.Name == "Cans");
        Assert.Equal(UnitOfMeasure.BoxId, cans.UomId);
        Assert.Equal(24m, cans.PackSize);
    }

    [Fact]
    public async Task Blank_rows_are_ignored()
    {
        var result = await ImportProducts(
            new ImportProductRow { Name = "  " },
            new ImportProductRow { Name = "Real" });

        Assert.Equal(1, result.Created);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public async Task Quantity_lands_in_the_first_warehouse()
    {
        await ImportProducts(new ImportProductRow { Name = "Sugar", Quantity = 40m });

        using var db = Db();
        Assert.Equal(40m, db.Stocks.Single().Quantity);
    }

    [Fact]
    public async Task A_count_records_the_stock_it_was_counted_against()
    {
        // Sugar holds 12 before the count. Salt has never been stocked. Rice's
        // row carries no quantity, so the import leaves its stock alone.
        await ImportProducts(new ImportProductRow { Name = "Sugar", Quantity = 12m });
        SeedCountPrerequisites();

        var result = await ImportCount(
            new ImportProductRow { Name = "Sugar", Quantity = 9m },
            new ImportProductRow { Name = "Salt", Quantity = 4m },
            new ImportProductRow { Name = "Rice" });

        Assert.Empty(result.Errors);
        Assert.NotNull(result.DocumentNumber);

        using var db = Db();
        var lines = db.DocumentItems.AsNoTracking()
            .Join(db.Products.AsNoTracking(), i => i.ProductId, p => p.Id,
                (i, p) => new { p.Name, i.Quantity, i.ExpectedQuantity })
            .ToList()
            .ToDictionary(x => x.Name);

        // Counted 9 against 12 — three left stock. It used to say "expected 9",
        // which made the variance unknowable.
        Assert.Equal(9m, lines["Sugar"].Quantity);
        Assert.Equal(12m, lines["Sugar"].ExpectedQuantity);
        // Nothing was there, so the whole count is an opening balance.
        Assert.Equal(4m, lines["Salt"].Quantity);
        Assert.Equal(0m, lines["Salt"].ExpectedQuantity);
        // No stock written, so no move: it expects exactly what it counted.
        Assert.Equal(lines["Rice"].Quantity, lines["Rice"].ExpectedQuantity);
        // And the stock itself is still overwritten with the count.
        Assert.Equal(9m, db.Stocks.AsNoTracking()
            .Single(s => s.ProductId == db.Products.Single(p => p.Name == "Sugar").Id)
            .Quantity);
    }

    // ═══ Product groups ═════════════════════════════════════════════════════

    [Fact]
    public async Task Parents_resolve_whatever_order_the_rows_come_in()
    {
        var result = await ImportGroups(
            G("Tea", parent: "Hot"),
            G("Hot", parent: "Drinks"),
            G("Drinks"));

        Assert.Equal(3, result.Created);
        Assert.Empty(result.Errors);
        var parents = ParentByName();
        Assert.Null(parents["Drinks"]);
        Assert.Equal("Drinks", parents["Hot"]);
        Assert.Equal("Hot", parents["Tea"]);
    }

    [Fact]
    public async Task A_parent_no_row_defines_is_created_at_the_root()
    {
        var result = await ImportGroups(G("Tea", parent: "Hot"));

        Assert.Equal(2, result.Created);
        Assert.Contains(result.Warnings, w => w.Contains("Hot"));
        var parents = ParentByName();
        Assert.Null(parents["Hot"]);
        Assert.Equal("Hot", parents["Tea"]);
    }

    [Fact]
    public async Task A_loop_is_refused_and_reported()
    {
        var result = await ImportGroups(G("A", parent: "B"), G("B", parent: "A"));

        Assert.Single(result.Errors);
        // Whatever was linked, walking up from either group must end.
        var parents = ParentByName();
        foreach (var start in new[] { "A", "B" })
        {
            var seen = new HashSet<string>();
            for (string? at = start; at != null; at = parents[at])
                Assert.True(seen.Add(at), $"a loop through {at}");
        }
    }

    [Fact]
    public async Task A_group_cannot_be_its_own_parent()
    {
        var result = await ImportGroups(G("Solo", parent: "solo"));

        Assert.Single(result.Errors);
        Assert.Empty(ParentByName());
    }

    [Fact]
    public async Task Skipping_leaves_an_existing_group_exactly_as_it_was()
    {
        var hot = AddGroup("Hot");
        AddGroup("Tea", hot);

        var result = await ImportGroups(G("Tea", parent: null, color: "#FF0000"), G("Cold"));

        Assert.Equal(1, result.Skipped);
        Assert.Equal(1, result.Created);
        using var db = Db();
        var tea = db.ProductGroups.Single(g => g.Name == "Tea");
        Assert.Equal("Transparent", tea.Color);
        Assert.Equal(hot, tea.ParentGroupId);
    }

    [Fact]
    public async Task Merging_updates_colour_rank_and_a_named_parent()
    {
        AddGroup("Tea");
        AddGroup("Hot");

        var result = await ImportGroups(merge: true, skip: false,
            G("Tea", parent: "Hot", color: "#00FF00", rank: 4));

        Assert.Equal(1, result.Updated);
        using var db = Db();
        var tea = db.ProductGroups.Single(g => g.Name == "Tea");
        Assert.Equal("#00FF00", tea.Color);
        Assert.Equal(4, tea.Rank);
        Assert.Equal("Hot", ParentByName()["Tea"]);
    }

    [Fact]
    public async Task A_blank_parent_never_moves_an_existing_group_to_the_root()
    {
        // "The file does not say" is not "move it to the top".
        var hot = AddGroup("Hot");
        AddGroup("Tea", hot);

        await ImportGroups(merge: true, skip: false, G("Tea", parent: null, color: "#123456"));

        Assert.Equal("Hot", ParentByName()["Tea"]);
    }

    [Fact]
    public async Task A_name_twice_in_the_file_uses_the_first_row()
    {
        var result = await ImportGroups(G("Snacks", color: "#111111"), G("snacks", color: "#222222"));

        Assert.Equal(1, result.Created);
        Assert.Single(result.Warnings);
        using var db = Db();
        Assert.Equal("#111111", db.ProductGroups.Single().Color);
    }

    [Fact]
    public async Task Importing_the_same_file_twice_creates_nothing_new()
    {
        var rows = new[] { G("Drinks"), G("Hot", parent: "Drinks") };
        await ImportGroups(rows);

        var again = await ImportGroups(rows);

        Assert.Equal(0, again.Created);
        Assert.Equal(2, again.Skipped);
        Assert.Equal(2, ParentByName().Count);
    }

    [Fact]
    public async Task An_over_long_name_is_an_error_not_a_crash()
    {
        var result = await ImportGroups(G(new string('n', 256)), G("Fine"));

        Assert.Single(result.Errors);
        Assert.Equal(1, result.Created);
    }

    // ═══ Group export ═══════════════════════════════════════════════════════

    private async Task<List<ProductGroupExportDto>> ExportGroups()
    {
        await using var db = Db();
        return await new GetProductGroupsForExportQueryHandler(db).Handle(
            new GetProductGroupsForExportQuery { CompanyId = _company }, default);
    }

    [Fact]
    public async Task The_export_lists_every_parent_before_its_children()
    {
        // Created leaf-first, so id order is exactly the wrong order.
        var tea = AddGroup("Tea");
        var hot = AddGroup("Hot");
        var drinks = AddGroup("Drinks");
        using (var db = Db())
        {
            db.ProductGroups.Single(g => g.Id == tea).Update("Tea", hot, "Transparent", null, 0, _company);
            db.ProductGroups.Single(g => g.Id == hot).Update("Hot", drinks, "Transparent", null, 0, _company);
            db.SaveChanges();
        }

        var exported = await ExportGroups();

        var order = exported.Select(g => g.Name).ToList();
        Assert.True(order.IndexOf("Drinks") < order.IndexOf("Hot"));
        Assert.True(order.IndexOf("Hot") < order.IndexOf("Tea"));
        Assert.Equal("Hot", exported.Single(g => g.Name == "Tea").ParentGroupName);
    }

    [Fact]
    public async Task A_loop_already_in_the_data_still_exports_every_group()
    {
        var a = AddGroup("A");
        var b = AddGroup("B", a);
        using (var db = Db())
        {
            db.ProductGroups.Single(g => g.Id == a).Update("A", b, "Transparent", null, 0, _company);
            db.SaveChanges();
        }

        var exported = await ExportGroups();

        Assert.Equal(2, exported.Count);
    }

    [Fact]
    public async Task The_export_counts_each_groups_products()
    {
        await ImportProducts(
            new ImportProductRow { Name = "Tea 1", ProductGroupName = "Tea" },
            new ImportProductRow { Name = "Tea 2", ProductGroupName = "Tea" });

        var exported = await ExportGroups();

        Assert.Equal(2, exported.Single(g => g.Name == "Tea").ProductCount);
    }

    [Fact]
    public async Task An_exported_group_file_imports_back_into_an_empty_company_intact()
    {
        // The round trip the feature exists for: out of one shop, into a fresh one.
        await ImportGroups(G("Drinks", color: "#0000FF", rank: 2), G("Hot", parent: "Drinks"), G("Tea", parent: "Hot"));
        var exported = await ExportGroups();

        using (var db = Db())
        {
            db.ProductGroups.RemoveRange(db.ProductGroups);
            db.SaveChanges();
        }

        var result = await ImportGroups(exported
            .Select(g => G(g.Name, g.ParentGroupName, g.Color, g.Rank))
            .ToArray());

        Assert.Equal(3, result.Created);
        var parents = ParentByName();
        Assert.Equal("Drinks", parents["Hot"]);
        Assert.Equal("Hot", parents["Tea"]);
        using var read = Db();
        Assert.Equal("#0000FF", read.ProductGroups.Single(g => g.Name == "Drinks").Color);
    }
}
