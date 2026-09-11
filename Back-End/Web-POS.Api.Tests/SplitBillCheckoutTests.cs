using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using Api.Repository;
using Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// A split bill: one table's sale, banked as ONE document that carries a payment
/// for every guest — so the document's Payments tab lists each of them.
///
/// <para>Before 2026-09-11 a checkout could only ever create one payment, from
/// PaymentTypeId / AmountPaid. The terminal now sends the full list of tenders,
/// and the ordinary single-tender sale must bank exactly as it always did.</para>
/// </summary>
public class SplitBillCheckoutTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;
    private readonly int _company;
    private readonly int _warehouse;
    private readonly int _user;
    private readonly int _product;
    private readonly int _cash;
    private readonly int _card;
    private readonly int _account; // a credit/tab type: MarkAsPaid = false

    public SplitBillCheckoutTests()
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

        var warehouse = Warehouse.Create(_company, "Main");
        db.Warehouses.Add(warehouse);
        var user = User.Create(_company, "Front", "Desk", "cashier", "hash", 1, true, null);
        db.Users.Add(user);
        db.DocumentCategories.Add(new DocumentCategory { Id = 2, Name = "Sales" });
        var sales = DocumentType.Create("Sales", DocumentTypeConstants.SalesCode, 2, stockDirection: 2);
        sales.Id = DocumentTypeConstants.Sales;
        db.DocumentTypes.Add(sales);

        PaymentType Type(string name, bool markAsPaid) => PaymentType.Create(
            _company, name, null, iscustomerrequired: false, isfiscal: false, issliprequired: false,
            ischnageallowed: true, ordinal: 0, isenabled: true, isquickpayment: false,
            opencashdrawer: false, shortcutkey: null, markaspaid: markAsPaid);
        var cash = Type("Cash", markAsPaid: true);
        var card = Type("Card", markAsPaid: true);
        var account = Type("Account", markAsPaid: false);
        db.PaymentTypes.AddRange(cash, card, account);

        var product = Product.Create(
            productGroupId:        null,
            name:                  "Couscous",
            code:                  null,
            plu:                   null,
            measurementUnit:       null,
            price:                 100m,
            isTaxInclusivePrice:   true,
            currencyId:            null,
            isPriceChangeAllowed:  false,
            isService:             false,
            isUsingDefaultQuantity:true,
            isEnabled:             true,
            description:           null,
            dateCreated:           DateTime.UtcNow,
            dateUpdated:           DateTime.UtcNow,
            cost:                  40m,
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

        _warehouse = warehouse.Id;
        _user = user.Id;
        _product = product.Id;
        _cash = cash.Id;
        _card = card.Id;
        _account = account.Id;
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private AppDbContext Db() => new(_options);

    private static CheckoutPaymentDto Pay(int typeId, decimal amount) =>
        new() { PaymentTypeId = typeId, Amount = amount };

    /// <summary>Banks a one-line order worth 100.00 with these tenders; an
    /// empty list is the ordinary sale, paid in cash.</summary>
    private async Task<CheckoutResult> Checkout(params CheckoutPaymentDto[] tenders)
    {
        const decimal total = 100m;
        await using var db = Db();
        var order = PosOrder.Create(_company, _user, $"ORD-{Guid.NewGuid():N}", 0, 0, total, null, 0, 0);
        db.PosOrders.Add(order);
        await db.SaveChangesAsync();
        db.PosOrderItems.Add(PosOrderItem.Create(_company, order.Id, _product, 1, 1m, total, 0, 0, 0, null, null));
        await db.SaveChangesAsync();

        var service = new PosOrderCheckoutService(
            db, new DocumentsCounterRepository(db), NullLogger<PosOrderCheckoutService>.Instance);
        return await service.CheckoutAsync(_company, _user, new CheckoutPosOrderRequest
        {
            PosOrderId = order.Id,
            PaymentTypeId = tenders.Length > 0 ? tenders[0].PaymentTypeId : _cash,
            AmountPaid = tenders.Length > 0 ? tenders.Sum(t => t.Amount) : total,
            GrandTotal = total,
            DocumentTypeId = DocumentTypeConstants.Sales,
            WarehouseId = _warehouse,
            ClientDocumentNumber = $"T-{Guid.NewGuid():N}",
            Payments = tenders.ToList(),
            Items =
            [
                new CheckoutItemDto
                {
                    ProductId = _product,
                    PriceBeforeTaxAfterDiscount = total,
                    PriceAfterDiscount = total,
                    Total = total,
                    TotalAfterDocumentDiscount = total,
                },
            ],
        });
    }

    private (List<Payment> Payments, int PaidStatus) Banked(int documentId)
    {
        using var db = Db();
        var payments = db.Payments.AsNoTracking()
            .Where(p => p.DocumentId == documentId)
            .OrderBy(p => p.Id)
            .ToList();
        var paidStatus = db.Documents.AsNoTracking().Single(d => d.Id == documentId).PaidStatus;
        return (payments, paidStatus);
    }

    [Fact]
    public async Task Every_guest_is_a_payment_on_the_one_document()
    {
        var result = await Checkout(Pay(_cash, 40m), Pay(_card, 60m));

        var (payments, paidStatus) = Banked(result.DocumentId);
        Assert.Equal([_cash, _card], payments.Select(p => p.PaymentTypeId));
        Assert.Equal([40m, 60m], payments.Select(p => p.Amount));
        Assert.Equal(PaidStatusConstants.Paid, paidStatus);
    }

    [Fact]
    public async Task A_share_put_on_account_leaves_the_document_partly_paid()
    {
        var result = await Checkout(Pay(_cash, 40m), Pay(_account, 0m));

        var (payments, paidStatus) = Banked(result.DocumentId);
        Assert.Equal(2, payments.Count);
        Assert.Equal(PaidStatusConstants.Partial, paidStatus);
    }

    [Fact]
    public async Task Every_share_on_account_leaves_it_unpaid()
    {
        var result = await Checkout(Pay(_account, 0m), Pay(_account, 0m));

        Assert.Equal(PaidStatusConstants.Unpaid, Banked(result.DocumentId).PaidStatus);
    }

    [Fact]
    public async Task An_ordinary_sale_still_banks_its_single_payment()
    {
        var result = await Checkout();

        var (payments, paidStatus) = Banked(result.DocumentId);
        var payment = Assert.Single(payments);
        Assert.Equal(_cash, payment.PaymentTypeId);
        Assert.Equal(100m, payment.Amount);
        Assert.Equal(PaidStatusConstants.Paid, paidStatus);
    }
}
