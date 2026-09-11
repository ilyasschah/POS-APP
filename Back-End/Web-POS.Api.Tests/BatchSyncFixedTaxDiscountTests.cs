using Api.Commands.PosOrderCommands.BatchSync;
using Api.Models;
using Xunit;

namespace Api.Tests;

/// <summary>
/// An offline sale's percentage item discount reaches the server as the
/// percentage, and <c>BuildCheckoutItems</c> turns it back into money. A fixed
/// tax is Rate × quantity whatever the discount — a rule the owner locked in on
/// 2026-09-11 — so on a tax-inclusive line, whose price carries that tax, the %
/// must be taken from the price WITHOUT it. That is the till's
/// <c>discountableUnitPrice</c>; disagreeing with it banks a line that differs
/// from what the customer paid.
/// </summary>
public class BatchSyncFixedTaxDiscountTests
{
    private const int EcoFee = 7; // fixed 2.00
    private const int Vat = 8;    // 20%
    private static readonly Dictionary<int, decimal> FixedRates = new() { [EcoFee] = 2m };

    /// <summary>10 × 52.00 at 10% off, carrying <paramref name="taxId"/>.</summary>
    private static CheckoutItemDto Line(bool? inclusive, HashSet<int> inclusiveProducts, int taxId)
    {
        var order = new BatchSyncOrderItem
        {
            LocalId = "order",
            Order = new CreatePosOrderRequest { UserId = 1, WarehouseId = 1 },
            Items =
            [
                new BulkAddPosOrderItemRequest
                {
                    ProductId = 1,
                    Quantity = 10m,
                    Price = 52m,
                    Discount = 10m,
                    DiscountType = 0,
                    IsTaxInclusive = inclusive,
                    Taxes = [new BatchSyncItemTaxDto { TaxId = taxId, Amount = 0m }],
                },
            ],
        };
        return BatchSyncPosOrdersCommand.Handler
            .BuildCheckoutItems(order, FixedRates, inclusiveProducts)
            .Single();
    }

    [Fact]
    public void An_inclusive_line_takes_the_percentage_from_the_price_without_its_fixed_tax()
    {
        var line = Line(inclusive: true, [], EcoFee);

        // 52 − 10% of 50: the fixed 2.00 is never discounted.
        Assert.Equal(47m, line.PriceAfterDiscount);
        Assert.Equal(470m, line.Total);
    }

    [Fact]
    public void An_exclusive_line_never_carried_it_so_the_whole_price_is_the_base()
    {
        var line = Line(inclusive: false, [1], EcoFee);

        Assert.Equal(46.8m, line.PriceAfterDiscount);
    }

    [Fact]
    public void An_older_client_falls_back_to_the_products_own_flag()
    {
        var line = Line(inclusive: null, [1], EcoFee);

        Assert.Equal(47m, line.PriceAfterDiscount);
    }

    [Fact]
    public void A_percentage_tax_alone_changes_nothing()
    {
        var line = Line(inclusive: true, [1], Vat);

        Assert.Equal(46.8m, line.PriceAfterDiscount);
    }
}
