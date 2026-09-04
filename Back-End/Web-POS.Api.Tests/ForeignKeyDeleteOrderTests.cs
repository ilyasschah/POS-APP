using Api.Services;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Pins the ordering that lets a company delete / data reset run WITHOUT
/// disabling foreign keys.
///
/// This is the whole point of the change these tests guard: the purge used to
/// run `ALTER TABLE … NOCHECK CONSTRAINT ALL`, which needs ALTER on ~50 tables.
/// Production's API login is only db_datareader + db_datawriter, so that failed
/// outright. Deleting children before parents needs nothing beyond DELETE.
///
/// The sort is tested as a pure function because the suite runs on SQLite,
/// which has no sys.foreign_keys. The edges below are the real ones, read from
/// the live web-pos schema.
/// </summary>
public class ForeignKeyDeleteOrderTests
{
    /// Asserts child is emptied before parent — i.e. appears EARLIER in the order.
    private static void AssertBefore(List<string> order, string child, string parent)
    {
        var ci = order.IndexOf(child);
        var pi = order.IndexOf(parent);
        Assert.True(ci >= 0, $"'{child}' missing from the order");
        Assert.True(pi >= 0, $"'{parent}' missing from the order");
        Assert.True(ci < pi,
            $"'{child}' references '{parent}', so it must be deleted first, " +
            $"but the order was [{string.Join(", ", order)}]");
    }

    [Fact]
    public void Children_are_deleted_before_the_parents_they_reference()
    {
        var order = ForeignKeyDeleteOrder.Resolve(
            ["Document", "DocumentItem", "DocumentItemTax"],
            [("DocumentItem", "Document"), ("DocumentItemTax", "DocumentItem")]);

        AssertBefore(order, "DocumentItemTax", "DocumentItem");
        AssertBefore(order, "DocumentItem", "Document");
        Assert.Equal(3, order.Count);
    }

    [Fact]
    public void Every_selected_table_is_emitted_exactly_once()
    {
        var tables = new[] { "Document", "DocumentItem", "Payment", "PosOrder" };
        var order = ForeignKeyDeleteOrder.Resolve(
            tables,
            [("DocumentItem", "Document"), ("Payment", "Document"), ("Payment", "PosOrder")]);

        Assert.Equal(tables.Length, order.Count);
        Assert.Equal(tables.OrderBy(t => t), order.OrderBy(t => t));
    }

    /// ProductGroup.ParentId points at ProductGroup. There is no order that
    /// resolves that, and none is needed: one DELETE removes the whole hierarchy
    /// in a single statement and SQL Server validates once it completes.
    [Fact]
    public void A_self_reference_does_not_deadlock_the_sort()
    {
        var order = ForeignKeyDeleteOrder.Resolve(
            ["ProductGroup", "Product"],
            [("ProductGroup", "ProductGroup"), ("Product", "ProductGroup")]);

        Assert.Equal(2, order.Count);
        AssertBefore(order, "Product", "ProductGroup");
    }

    /// A reset clears a SUBSET. Edges pointing outside it are not this
    /// operation's problem — the group lists are closed under their own
    /// dependencies, which CompanyDataResetServiceTests covers.
    [Fact]
    public void Edges_to_tables_outside_the_selection_are_ignored()
    {
        var order = ForeignKeyDeleteOrder.Resolve(
            ["Document", "DocumentItem"],
            [("DocumentItem", "Document"), ("DocumentItem", "Product"), ("Booking", "Document")]);

        Assert.Equal(2, order.Count);
        AssertBefore(order, "DocumentItem", "Document");
        Assert.DoesNotContain("Product", order);
        Assert.DoesNotContain("Booking", order);
    }

    /// Refusing beats guessing. With constraints previously switched off a cycle
    /// could not be noticed; now it has to be reported rather than silently
    /// emitting an order that will throw halfway through a destructive delete.
    [Fact]
    public void A_cycle_is_reported_rather_than_half_ordered()
    {
        var ex = Assert.Throws<InvalidOperationException>(() =>
            ForeignKeyDeleteOrder.Resolve(
                ["A", "B"],
                [("A", "B"), ("B", "A")]));

        Assert.Contains("cycle", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("A", ex.Message);
        Assert.Contains("B", ex.Message);
    }

    [Fact]
    public void Order_is_deterministic_when_several_tables_are_equally_free()
    {
        string[] tables = ["Zebra", "Alpha", "Mango"];
        var first = ForeignKeyDeleteOrder.Resolve(tables, []);
        var again = ForeignKeyDeleteOrder.Resolve(tables.Reverse().ToArray(), []);

        Assert.Equal(first, again);
    }

    [Fact]
    public void An_empty_selection_is_not_an_error()
    {
        Assert.Empty(ForeignKeyDeleteOrder.Resolve([], []));
    }

    [Fact]
    public void Unsafe_table_names_are_refused_before_reaching_sql()
    {
        ForeignKeyDeleteOrder.AssertSafeIdentifier("DocumentItem");   // does not throw

        foreach (var bad in new[] { "Document Item", "Document;DROP", "[Document]", "1Table", "" })
        {
            Assert.Throws<InvalidOperationException>(
                () => ForeignKeyDeleteOrder.AssertSafeIdentifier(bad));
        }
    }

    // ── The real schema ───────────────────────────────────────────────────────

    /// The foreign keys the company purge actually has to respect, read from the
    /// live web-pos database (sys.foreign_keys, 2026-09-03). Not exhaustive —
    /// these are the ones whose ordering a regression would most likely break.
    private static readonly (string Child, string Parent)[] LiveEdges =
    [
        ("DocumentItem", "Document"), ("DocumentItemTax", "DocumentItem"),
        ("DocumentItemModifier", "DocumentItem"), ("DocumentItemExpirationDate", "DocumentItem"),
        ("PosOrderItem", "PosOrder"), ("PosOrderItemTax", "PosOrderItem"),
        ("PosOrderItemModifier", "PosOrderItem"),
        ("Payment", "Document"), ("DiscountLine", "Document"),
        ("DocumentItem", "Product"), ("PosOrderItem", "Product"), ("PosVoid", "Product"),
        ("Product", "ProductGroup"), ("ProductGroup", "ProductGroup"),
        ("Barcode", "Product"), ("ProductTax", "Product"),
        ("Stock", "Product"), ("StockControl", "Product"),
        ("PromotionItem", "Promotion"), ("PromotionItem", "Product"),
        ("Document", "Customer"), ("PosOrder", "Customer"), ("StockControl", "Customer"),
        ("CustomerDiscount", "Customer"), ("LoyaltyCard", "Customer"),
        ("Document", "Shift"), ("Payment", "Shift"), ("PosOrder", "Shift"),
        ("ZReport", "Shift"), ("ZReportCorrection", "Shift"),
        ("PosSessionPaymentCount", "Shift"), ("StartingCash", "Shift"),
        ("Booking", "PosOrder"),
    ];

    [Fact]
    public void Live_schema_orders_the_sales_graph_children_first()
    {
        string[] tables =
        [
            "Document", "DocumentItem", "DocumentItemTax", "DocumentItemModifier",
            "DocumentItemExpirationDate", "Payment", "DiscountLine",
            "PosOrder", "PosOrderItem", "PosOrderItemTax", "PosOrderItemModifier",
        ];

        var order = ForeignKeyDeleteOrder.Resolve(tables, LiveEdges);

        AssertBefore(order, "DocumentItemTax", "DocumentItem");
        AssertBefore(order, "DocumentItemModifier", "DocumentItem");
        AssertBefore(order, "DocumentItemExpirationDate", "DocumentItem");
        AssertBefore(order, "DocumentItem", "Document");
        AssertBefore(order, "Payment", "Document");
        AssertBefore(order, "DiscountLine", "Document");
        AssertBefore(order, "PosOrderItemTax", "PosOrderItem");
        AssertBefore(order, "PosOrderItemModifier", "PosOrderItem");
        AssertBefore(order, "PosOrderItem", "PosOrder");
    }

    /// Everything that references Shift must go before it, or the filtered
    /// session delete at the end of ResetAsync throws.
    [Fact]
    public void Live_schema_empties_every_session_referencer_before_Shift()
    {
        string[] tables =
        [
            "Shift", "Document", "Payment", "PosOrder", "ZReport",
            "ZReportCorrection", "PosSessionPaymentCount", "StartingCash",
        ];

        var order = ForeignKeyDeleteOrder.Resolve(tables, LiveEdges);

        foreach (var child in new[]
                 {
                     "Document", "Payment", "PosOrder", "ZReport",
                     "ZReportCorrection", "PosSessionPaymentCount", "StartingCash",
                 })
        {
            AssertBefore(order, child, "Shift");
        }
    }

    /// The catalogue: sales rows reference Product, Product references
    /// ProductGroup, and ProductGroup references itself.
    [Fact]
    public void Live_schema_orders_the_catalogue_including_the_self_reference()
    {
        string[] tables =
        [
            "ProductGroup", "Product", "Barcode", "ProductTax", "Stock",
            "StockControl", "PromotionItem", "Promotion", "DocumentItem",
            "PosOrderItem", "PosVoid",
        ];

        var order = ForeignKeyDeleteOrder.Resolve(tables, LiveEdges);

        Assert.Equal(tables.Length, order.Count);
        foreach (var child in new[]
                 {
                     "Barcode", "ProductTax", "Stock", "StockControl",
                     "PromotionItem", "DocumentItem", "PosOrderItem", "PosVoid",
                 })
        {
            AssertBefore(order, child, "Product");
        }
        AssertBefore(order, "Product", "ProductGroup");
        AssertBefore(order, "PromotionItem", "Promotion");
    }

    /// Booking survives a documents reset (it is a future reservation, not a
    /// sale) and its PosOrderId is nulled instead. But in a FULL company delete
    /// it goes too, and it must precede PosOrder.
    [Fact]
    public void Live_schema_deletes_Booking_before_PosOrder_in_a_full_purge()
    {
        var order = ForeignKeyDeleteOrder.Resolve(
            ["Booking", "PosOrder", "PosOrderItem"], LiveEdges);

        AssertBefore(order, "Booking", "PosOrder");
        AssertBefore(order, "PosOrderItem", "PosOrder");
    }
}
