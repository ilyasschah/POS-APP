using Api.DataBase;
using Api.Domain;
using Api.Repository;
using Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Deleting a tax that is still in use is refused up front, with a message that
/// names the tax and the cause.
///
/// 🚨 The bug these were written for (2026-09-12): deleting a tax assigned to a
/// product reached SQL Server, failed on <c>FK_ProductTax_Tax</c>, was logged as
/// an EF failure with a full stack trace, and came back as the generic "still
/// referenced by other data" — which the POS then never showed.
/// </summary>
public class TaxDeletionTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;
    private readonly int _company;
    private readonly int _product;

    public TaxDeletionTests()
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
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private AppDbContext Db() => new(_options);

    private static TaxService Service(AppDbContext db) =>
        new(new TaxRepository(db), new CompanyRepository(db));

    private int SeedTax(string name, string code)
    {
        using var db = Db();
        var tax = Tax.Create(_company, name, 20, code, false, false, true);
        db.Taxes.Add(tax);
        db.SaveChanges();
        return tax.Id;
    }

    private void AssignToProduct(int taxId)
    {
        using var db = Db();
        db.ProductsTaxes.Add(ProductTax.Create(_product, taxId, _company));
        db.SaveChanges();
    }

    [Fact]
    public async Task An_unused_tax_is_deleted()
    {
        var taxId = SeedTax("TVA 20", "T20");
        using var db = Db();

        Assert.True(await Service(db).DeleteAsync(taxId, _company));

        using var check = Db();
        Assert.False(await check.Taxes.AnyAsync(t => t.Id == taxId));
    }

    [Fact]
    public async Task A_tax_a_product_uses_is_refused_by_name_before_reaching_the_database()
    {
        var taxId = SeedTax("TVA 20", "T20");
        AssignToProduct(taxId);
        using var db = Db();

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => Service(db).DeleteAsync(taxId, _company));

        // An InvalidOperationException is the middleware's 400 { success, message }.
        Assert.Contains("TVA 20", ex.Message);
        Assert.Contains("1 product(s)", ex.Message);
        using var check = Db();
        Assert.True(await check.Taxes.AnyAsync(t => t.Id == taxId));
        Assert.True(await check.ProductsTaxes.AnyAsync(pt => pt.TaxId == taxId));
    }

    [Fact]
    public async Task Usage_counts_only_the_tax_asked_about()
    {
        var used = SeedTax("TVA 20", "T20");
        var unused = SeedTax("TVA 10", "T10");
        AssignToProduct(used);
        using var db = Db();
        var repo = new TaxRepository(db);

        Assert.Equal((1, 0), await repo.GetUsageAsync(used));
        Assert.Equal((0, 0), await repo.GetUsageAsync(unused));
    }

    [Fact]
    public async Task An_unknown_tax_reports_not_found()
    {
        using var db = Db();

        Assert.False(await Service(db).DeleteAsync(999, _company));
    }
}
