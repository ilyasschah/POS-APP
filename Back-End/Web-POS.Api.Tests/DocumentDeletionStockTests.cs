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
/// Deleting a document gives back the stock its lines moved — exactly what
/// deleting each of its lines one by one gives back.
///
/// <para>Before 2026-09-11 the lines cascaded away with the document while
/// their stock stayed where they had put it, so stock on hand stopped adding up
/// to the Stock Moves history that was left.</para>
///
/// <para>Every line here is added through <see cref="DocumentItemService"/>,
/// the way the API adds one, because that is also what moves its stock in the
/// first place — a delete that undoes anything else would pass for the wrong
/// reason.</para>
/// </summary>
public class DocumentDeletionStockTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;
    private readonly int _company;
    private readonly int _warehouse;
    private readonly int _annex;
    private readonly int _user;
    private readonly int _tea;   // counted in pieces
    private readonly int _flour; // counted in kilograms

    public DocumentDeletionStockTests()
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
        var annex = Warehouse.Create(_company, "Annex");
        db.Warehouses.AddRange(main, annex);
        var user = User.Create(_company, "Stock", "Keeper", "keeper", "hash", 1, true, null);
        db.Users.Add(user);

        // What the seeder provides in production and nothing does in here.
        foreach (var (id, name) in new[] { (1, "Expenses"), (2, "Sales"), (3, "Inventory"), (4, "Loss") })
            db.DocumentCategories.Add(new DocumentCategory { Id = id, Name = name });
        foreach (var (id, name, code, category, direction) in new[]
                 {
                     (DocumentTypeConstants.Purchase, "Purchase", "100", 1, 1),
                     (DocumentTypeConstants.Sales, "Sales", "200", 2, 2),
                     (DocumentTypeConstants.Refund, "Refund", "220", 2, 1),
                     (DocumentTypeConstants.StockReturn, "Stock Return", "120", 1, 2),
                     (DocumentTypeConstants.LossAndDamage, "Loss And Damage", "400", 4, 2),
                 })
        {
            var type = DocumentType.Create(name, code, category, stockDirection: direction);
            type.Id = id;
            db.DocumentTypes.Add(type);
        }
        db.SaveChanges();
        _warehouse = main.Id;
        _annex = annex.Id;
        _user = user.Id;

        _tea = AddProduct(db, "Mint tea", UnitOfMeasure.PiecesId);
        _flour = AddProduct(db, "Flour", UnitOfMeasure.KilogramId);
        db.Stocks.AddRange(
            Stock.Create(100m, _warehouse, _tea, _company),
            Stock.Create(7m, _annex, _tea, _company),
            Stock.Create(20m, _warehouse, _flour, _company));
        db.SaveChanges();
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private AppDbContext Db() => new(_options);

    private int AddProduct(AppDbContext db, string name, int uomId)
    {
        var product = Product.Create(
            productGroupId:        null,
            name:                  name,
            code:                  null,
            plu:                   null,
            measurementUnit:       null,
            price:                 10m,
            isTaxInclusivePrice:   true,
            currencyId:            null,
            isPriceChangeAllowed:  false,
            isService:             false,
            isUsingDefaultQuantity:true,
            isEnabled:             true,
            description:           null,
            dateCreated:           DateTime.UtcNow,
            dateUpdated:           DateTime.UtcNow,
            cost:                  5m,
            markup:                null,
            image:                 null,
            color:                 "Transparent",
            ageRestriction:        null,
            lastPurchasePrice:     null,
            rank:                  0,
            uomId:                 uomId,
            isToWeigh:             false,
            packSize:              null);
        product.CompanyId = _company;
        db.Products.Add(product);
        db.SaveChanges();
        return product.Id;
    }

    private static DocumentItemService Items(AppDbContext db) =>
        new(new DocumentItemRepository(db), new ProductRepository(db), new DocumentRepository(db), db);

    private static DocumentService Documents(AppDbContext db) =>
        new(new DocumentRepository(db), Items(db), db);

    private int NewDocument(int typeId)
    {
        using var db = Db();
        var document = Document.Create(
            number: $"T-{Guid.NewGuid():N}",
            userId: _user,
            companyId: _company,
            documentTypeId: typeId,
            warehouseId: _warehouse,
            total: 0);
        db.Documents.Add(document);
        db.SaveChanges();
        return document.Id;
    }

    private async Task AddLine(int documentId, int productId, decimal quantity)
    {
        await using var db = Db();
        await Items(db).CreateAsync(new CreateDocumentItemRequest
        {
            DocumentId = documentId,
            ProductId = productId,
            Quantity = quantity,
            ExpectedQuantity = quantity,
            Price = 10m,
            PriceBeforeTax = 10m,
        }, _company);
    }

    private async Task DeleteDocument(int documentId)
    {
        await using var db = Db();
        await Documents(db).DeleteAsync(documentId, _company);
    }

    private decimal StockOf(int productId, int? warehouseId = null)
    {
        using var db = Db();
        return db.Stocks.AsNoTracking()
            .Single(s => s.ProductId == productId && s.WarehouseId == (warehouseId ?? _warehouse))
            .Quantity;
    }

    [Theory]
    [InlineData(DocumentTypeConstants.Purchase, 110)]      // received 10
    [InlineData(DocumentTypeConstants.StockReturn, 90)]    // sent 10 back to the vendor
    [InlineData(DocumentTypeConstants.LossAndDamage, 90)]  // wrote 10 off
    public async Task Deleting_a_document_gives_back_what_its_lines_moved(int typeId, int afterLine)
    {
        var doc = NewDocument(typeId);
        await AddLine(doc, _tea, 10m);
        Assert.Equal((decimal)afterLine, StockOf(_tea));

        await DeleteDocument(doc);

        Assert.Equal(100m, StockOf(_tea));
        using var db = Db();
        Assert.False(db.Documents.Any(d => d.Id == doc));
        Assert.False(db.DocumentItems.Any(i => i.DocumentId == doc));
    }

    [Fact]
    public async Task Every_line_counts_several_of_one_product_included()
    {
        var doc = NewDocument(DocumentTypeConstants.Purchase);
        await AddLine(doc, _tea, 3m);
        await AddLine(doc, _tea, 4m);
        await AddLine(doc, _flour, 2.5m);
        Assert.Equal(107m, StockOf(_tea));
        Assert.Equal(22.5m, StockOf(_flour));

        await DeleteDocument(doc);

        Assert.Equal(100m, StockOf(_tea));
        Assert.Equal(20m, StockOf(_flour));
    }

    [Fact]
    public async Task Only_the_documents_own_warehouse_moves()
    {
        var doc = NewDocument(DocumentTypeConstants.Purchase);
        await AddLine(doc, _tea, 10m);

        await DeleteDocument(doc);

        Assert.Equal(7m, StockOf(_tea, _annex));
    }

    [Theory]
    [InlineData(DocumentTypeConstants.Sales)]
    [InlineData(DocumentTypeConstants.Refund)]
    public async Task A_document_whose_lines_move_no_stock_gives_none_back(int typeId)
    {
        var doc = NewDocument(typeId);
        await AddLine(doc, _tea, 10m);

        await DeleteDocument(doc);

        Assert.Equal(100m, StockOf(_tea));
        using var db = Db();
        Assert.False(db.Documents.Any(d => d.Id == doc));
    }

    [Fact]
    public async Task Deleting_the_document_agrees_with_deleting_its_lines_one_by_one()
    {
        var byLine = NewDocument(DocumentTypeConstants.LossAndDamage);
        await AddLine(byLine, _tea, 6m);
        await using (var db = Db())
        {
            var lineId = db.DocumentItems.Single(i => i.DocumentId == byLine).Id;
            await Items(db).DeleteAsync(lineId, _company);
        }
        var afterLineDelete = StockOf(_tea);

        var whole = NewDocument(DocumentTypeConstants.LossAndDamage);
        await AddLine(whole, _tea, 6m);
        await DeleteDocument(whole);

        Assert.Equal(100m, afterLineDelete);
        Assert.Equal(afterLineDelete, StockOf(_tea));
    }

    [Fact]
    public async Task A_missing_document_is_refused_and_nothing_moves()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => DeleteDocument(987654));

        Assert.Equal(100m, StockOf(_tea));
    }
}
