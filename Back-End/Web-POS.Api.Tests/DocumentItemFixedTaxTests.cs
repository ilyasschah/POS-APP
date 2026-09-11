using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using Api.Repository;
using Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// A tax marked Fixed is a flat amount per unit on a document line — its Rate
/// times the quantity — never a percentage of the price.
///
/// <para>Before 2026-09-11 <see cref="DocumentItemTaxService"/> read every rate as
/// a percentage, so a 2.00 levy on 10 × 50.00 banked 10.00 (2% of 500) instead
/// of 20.00, and the line's Price and Total were rewritten from that figure.
/// This service is what the terminal calls when it pushes a purchase line's tax,
/// so the terminal's own math was overwritten on every sync.</para>
/// </summary>
public class DocumentItemFixedTaxTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;
    private readonly int _company;
    private readonly int _warehouse;
    private readonly int _user;
    private readonly int _product;

    public DocumentItemFixedTaxTests()
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

        var main = Warehouse.Create(_company, "Main");
        db.Warehouses.Add(main);
        var user = User.Create(_company, "Stock", "Keeper", "keeper", "hash", 1, true, null);
        db.Users.Add(user);

        // What the seeder provides in production and nothing does in here.
        db.DocumentCategories.Add(new DocumentCategory { Id = 1, Name = "Expenses" });
        var purchase = DocumentType.Create("Purchase", "100", 1, stockDirection: 1);
        purchase.Id = DocumentTypeConstants.Purchase;
        db.DocumentTypes.Add(purchase);
        db.SaveChanges();
        _warehouse = main.Id;
        _user = user.Id;

        var product = Product.Create(
            productGroupId:        null,
            name:                  "Soda",
            code:                  null,
            plu:                   null,
            measurementUnit:       null,
            price:                 60m,
            isTaxInclusivePrice:   false,
            currencyId:            null,
            isPriceChangeAllowed:  false,
            isService:             false,
            isUsingDefaultQuantity:true,
            isEnabled:             true,
            description:           null,
            dateCreated:           DateTime.UtcNow,
            dateUpdated:           DateTime.UtcNow,
            cost:                  50m,
            markup:                null,
            image:                 null,
            color:                 "Transparent",
            ageRestriction:        null,
            lastPurchasePrice:     null,
            rank:                  0,
            uomId:                 UnitOfMeasure.PiecesId,
            isToWeigh:             false,
            packSize:              null);
        product.CompanyId = _company;
        db.Products.Add(product);
        db.SaveChanges();
        _product = product.Id;
        db.Stocks.Add(Stock.Create(0m, _warehouse, _product, _company));
        db.SaveChanges();
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private AppDbContext Db() => new(_options);

    private static DocumentItemTaxService Taxes(AppDbContext db) =>
        new(new DocumentItemTaxRepository(db), new DocumentItemRepository(db), new TaxRepository(db));

    /// <summary>A purchase line of <paramref name="quantity"/> × 50.00, added the
    /// way the API adds one.</summary>
    private async Task<int> NewLine(decimal quantity, decimal discount = 0m, int discountType = 0)
    {
        await using var db = Db();
        var document = Document.Create(
            number: $"T-{Guid.NewGuid():N}",
            userId: _user,
            companyId: _company,
            documentTypeId: DocumentTypeConstants.Purchase,
            warehouseId: _warehouse,
            total: 0);
        db.Documents.Add(document);
        await db.SaveChangesAsync();

        await new DocumentItemService(
                new DocumentItemRepository(db), new ProductRepository(db), new DocumentRepository(db), db)
            .CreateAsync(new CreateDocumentItemRequest
            {
                DocumentId = document.Id,
                ProductId = _product,
                Quantity = quantity,
                ExpectedQuantity = quantity,
                PriceBeforeTax = 50m,
                Price = 50m,
                Discount = discount,
                DiscountType = discountType,
            }, _company);
        return db.DocumentItems.AsNoTracking().Single(i => i.DocumentId == document.Id).Id;
    }

    private int AddTax(string name, decimal rate, bool isFixed)
    {
        using var db = Db();
        var tax = Tax.Create(_company, name, rate, null, isFixed, istaxontotal: false, isenabled: true);
        db.Taxes.Add(tax);
        db.SaveChanges();
        return tax.Id;
    }

    private async Task<DocumentItemTaxDto> ApplyTax(int line, int tax)
    {
        await using var db = Db();
        return await Taxes(db).Create(new CreateDocumentItemTaxRequest { DocumentItemId = line, TaxId = tax }, _company);
    }

    private DocumentItem Line(int id)
    {
        using var db = Db();
        return db.DocumentItems.AsNoTracking().Single(i => i.Id == id);
    }

    [Fact]
    public async Task A_fixed_tax_is_its_rate_times_the_quantity()
    {
        var line = await NewLine(quantity: 10m);

        var applied = await ApplyTax(line, AddTax("Eco fee", 2m, isFixed: true));

        Assert.Equal(20m, applied.Amount);
        Assert.Equal(52m, Line(line).Price);
        Assert.Equal(520m, Line(line).Total);
    }

    [Fact]
    public async Task A_percentage_tax_is_unchanged()
    {
        var line = await NewLine(quantity: 10m);

        var applied = await ApplyTax(line, AddTax("VAT", 20m, isFixed: false));

        Assert.Equal(100m, applied.Amount);
        Assert.Equal(60m, Line(line).Price);
        Assert.Equal(600m, Line(line).Total);
    }

    [Fact]
    public async Task A_fixed_and_a_percentage_tax_on_one_line_each_keep_their_kind()
    {
        var line = await NewLine(quantity: 10m);

        await ApplyTax(line, AddTax("VAT", 20m, isFixed: false));
        await ApplyTax(line, AddTax("Eco fee", 2m, isFixed: true));

        // 50 × 1.20 + 2.00 — not 50 × 1.22.
        Assert.Equal(62m, Line(line).Price);
        Assert.Equal(620m, Line(line).Total);
    }

    [Fact]
    public async Task A_percentage_discount_never_shrinks_a_fixed_tax()
    {
        var line = await NewLine(quantity: 10m, discount: 10m, discountType: 0);

        await ApplyTax(line, AddTax("Eco fee", 2m, isFixed: true));

        // (50 − 5) + 2 per unit: the 10% comes off the price, the levy stays 2.00.
        Assert.Equal(52m, Line(line).Price);
        Assert.Equal(470m, Line(line).Total);
    }

    [Fact]
    public async Task Editing_a_line_keeps_a_percentage_discount_off_its_fixed_tax()
    {
        var line = await NewLine(quantity: 10m, discount: 10m, discountType: 0);
        await ApplyTax(line, AddTax("Eco fee", 2m, isFixed: true));

        // The editor re-sends the line with a new quantity, and the price it
        // sends carries the fixed tax (50 + 2).
        await using (var db = Db())
        {
            await new DocumentItemService(
                    new DocumentItemRepository(db), new ProductRepository(db), new DocumentRepository(db), db)
                .UpdateAsync(new UpdateDocumentItemRequest
                {
                    Id = line,
                    Quantity = 5m,
                    Price = 52m,
                    PriceBeforeTax = 50m,
                }, _company);
        }

        // (52 − 10% of 50) × 5 — not (52 − 10% of 52) × 5 = 234.
        Assert.Equal(235m, Line(line).Total);
    }

    [Fact]
    public async Task Updating_a_fixed_tax_recomputes_it_as_a_fixed_amount()
    {
        var line = await NewLine(quantity: 10m);
        var tax = AddTax("Eco fee", 2m, isFixed: true);
        await ApplyTax(line, tax);

        await using var db = Db();
        var updated = await Taxes(db).Update(
            new UpdateDocumentItemTaxRequest { DocumentItemId = line, TaxId = tax }, _company);

        Assert.Equal(20m, updated.Amount);
    }
}
