using Api.Services;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Pins the FK-closure rules behind Settings → Database → Reset database.
///
/// These matter because of how the purge works: constraints are disabled for
/// the deletes and re-armed afterwards with <c>WITH CHECK CHECK CONSTRAINT</c>,
/// which RE-VALIDATES every row. So a group that deletes a parent without its
/// referencing children does not fail at the delete — it fails at the very end,
/// on the re-enable, aborting a transaction that has already destroyed data.
///
/// The dependencies that force the cascades below, taken from the live schema:
///   FK_DocumentItem_Product, FK_PosOrderItem_Product, FK_PosVoid_Product
///     → deleting Product requires the sales rows to go too.
///   FK_Document_Customer, FK_PosOrder_Customer, FK_StockControl_Customer
///     → same for Customer.
///
/// <see cref="CompanyDataResetService.TablesFor"/> only touches the database on
/// the Everything branch, so every non-Everything case is exercised here with a
/// null context.
/// </summary>
public class CompanyDataResetServiceTests
{
    private static readonly CompanyDataResetService Service = new(null!);

    private static async Task<List<string>> Tables(
        bool products = false, bool customers = false, bool documents = false) =>
        await Service.TablesFor(new ResetCompanyDataOptions
        {
            Products = products,
            Customers = customers,
            Documents = documents,
        });

    [Fact]
    public async Task Products_drags_the_sales_rows_that_reference_them()
    {
        var tables = await Tables(products: true);

        Assert.Contains("Product", tables);
        // The three FKs that would blow up the re-enable if left behind.
        Assert.Contains("DocumentItem", tables);
        Assert.Contains("PosOrderItem", tables);
        Assert.Contains("PosVoid", tables);
        // And their parents, so no document survives with zero lines.
        Assert.Contains("Document", tables);
        Assert.Contains("PosOrder", tables);
    }

    [Fact]
    public async Task Customers_drags_everything_that_references_them()
    {
        var tables = await Tables(customers: true);

        Assert.Contains("Customer", tables);
        Assert.Contains("Document", tables);      // FK_Document_Customer
        Assert.Contains("PosOrder", tables);      // FK_PosOrder_Customer
        Assert.Contains("StockControl", tables);  // FK_StockControl_Customer
        Assert.Contains("CustomerDiscount", tables);
        Assert.Contains("LoyaltyCard", tables);
    }

    [Fact]
    public async Task Documents_alone_leaves_the_catalogue_standing()
    {
        var tables = await Tables(documents: true);

        Assert.Contains("Document", tables);
        Assert.Contains("ZReport", tables);
        // Clearing sales history must not quietly delete the products or the
        // customer list — nothing references Product FROM Document's side.
        Assert.DoesNotContain("Product", tables);
        Assert.DoesNotContain("Customer", tables);
    }

    [Fact]
    public async Task StockControl_appears_once_when_both_groups_claim_it()
    {
        // It is a member of the Customers group AND gets pulled in by Products.
        // A duplicate would issue the DELETE twice — harmless, but it would also
        // double-count the reported row total.
        var tables = await Tables(products: true, customers: true);

        Assert.Equal(tables.Count, tables.Distinct().Count());
        Assert.Single(tables, t => t == "StockControl");
    }

    [Fact]
    public async Task Survivors_are_never_in_any_group()
    {
        // Deleting User/UserDevicePins would destroy the admin account that just
        // authorised the reset and lock every device out of the company.
        var tables = await Tables(products: true, customers: true, documents: true);

        foreach (var survivor in CompanyDataResetService.NeverReset)
            Assert.DoesNotContain(survivor, tables);
    }

    [Fact]
    public async Task Selecting_nothing_resolves_to_nothing()
    {
        Assert.Empty(await Tables());
    }

    [Fact]
    public async Task Reset_refuses_an_empty_selection()
    {
        // The controller guards this too; belt and braces, because "no flags"
        // must never be interpreted as "all of it".
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => Service.ResetAsync(25, new ResetCompanyDataOptions()));
    }

    [Fact]
    public async Task Reset_refuses_an_invalid_company()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => Service.ResetAsync(0, new ResetCompanyDataOptions { Documents = true }));
    }

    [Fact]
    public async Task Documents_drags_the_modifier_lines()
    {
        // FK_DocumentItemModifier_DocumentItem_DocumentItemId and
        // FK_PosOrderItemModifier_PosOrderItem_PosOrderItemId. Both arrived with
        // the modifiers feature after this group was written, so a reset on a
        // shop that uses modifiers aborted on the WITH CHECK re-enable.
        var tables = await Tables(documents: true);

        Assert.Contains("DocumentItemModifier", tables);
        Assert.Contains("PosOrderItemModifier", tables);
    }

    [Fact]
    public async Task Documents_drags_everything_that_hangs_off_a_session()
    {
        // All three carry a FK to Shift, and the session itself is deleted by
        // ResetAsync. Left behind they orphan, and the re-enable throws.
        var tables = await Tables(documents: true);

        Assert.Contains("PosSessionPaymentCount", tables);  // FK_..._Shift_SessionId
        Assert.Contains("StartingCash", tables);            // FK_..._Shift_SessionId
        Assert.Contains("ZReportCorrection", tables);       // FK_..._Shift_SessionId
    }

    [Fact]
    public async Task Shift_is_never_a_whole_table_delete_outside_Everything()
    {
        // The table holds BOTH shapes. A blanket DELETE would take the payroll
        // record of every employee along with the register's sales history, so
        // the session purge is a filtered statement inside ResetAsync
        // (`PosDeviceId IS NOT NULL`) and Shift must stay out of every group.
        foreach (var tables in new[]
                 {
                     await Tables(documents: true),
                     await Tables(products: true),
                     await Tables(customers: true),
                     await Tables(products: true, customers: true, documents: true),
                 })
        {
            Assert.DoesNotContain("Shift", tables);
        }
    }
}
