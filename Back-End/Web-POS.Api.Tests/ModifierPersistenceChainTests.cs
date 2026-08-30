using System.Runtime.CompilerServices;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The chosen modifiers have to survive every hop from the till to the banked
/// document. This checks that each hop still carries them.
/// </summary>
/// <remarks>
/// 🚨 Why a source guard rather than a unit test. Losing them is invisible at
/// every layer that could normally catch it: the DTO field exists, so it binds;
/// a handler that never reads it compiles; the sale banks; the total is right,
/// because the surcharge is already inside the line price. The ONLY symptom is
/// a reprint or a kitchen ticket that shows a plain burger for a line sold — and
/// charged — with Extra Cheese. Nothing throws, nothing 500s, nothing fails a
/// test that does not know to look.
///
/// The chain is four hops and any one of them dropping the list is silent:
///   BulkAdd          → PosOrderItemModifier   (a parked order, for other tills)
///   BatchSync        → CheckoutItemDto        (an offline sale's only route in)
///   Checkout         → DocumentItemModifier   (the permanent record)
///   Refund           → DocumentItemModifier   (so a return reads like the sale)
///
/// These assert on the SOURCE because there is no relational test harness in
/// this project — every existing test here walks the model or the files. If one
/// is ever added, replace these with the real thing; until then a guard that
/// names the missing hop beats no guard at all.
/// </remarks>
public class ModifierPersistenceChainTests
{
    private static string ApiRoot([CallerFilePath] string thisFile = "")
    {
        var beside = Path.GetDirectoryName(Path.GetDirectoryName(thisFile));
        var candidate = Path.Combine(beside!, "Web-POS.Api");
        Assert.True(Directory.Exists(candidate),
            "Could not locate Web-POS.Api next to the test assembly — this guard "
            + "is not running. Fix the lookup rather than deleting the test.");
        return candidate;
    }

    private static string Read(params string[] parts) =>
        File.ReadAllText(Path.Combine(ApiRoot(), Path.Combine(parts)));

    [Fact]
    public void Checkout_writes_the_choices_onto_the_banked_line()
    {
        var source = Read("Services", "PosOrderCheckoutService.cs");

        Assert.Contains("DocumentItemModifier.Create", source);
        // From the PAYLOAD, never re-read from the catalogue by id: an offline
        // till may have sold against a catalogue this server has not seen, and
        // today's price is not what the customer was charged.
        Assert.Contains("frontendItem.Modifiers", source);
    }

    [Fact]
    public void A_parked_order_keeps_its_choices_for_the_next_till()
    {
        var source = Read("Commands", "PosOrderItemCommands", "Add",
                          "BulkAddPosOrderItemsCommand.cs");

        Assert.Contains("PosOrderItemModifier.Create", source);
        // Replaced wholesale like the taxes beside them — this command receives
        // the order's complete line list, so leftovers are the previous version
        // of a line that still exists.
        Assert.Contains("RemoveRange(oldModifiers)", source);
    }

    [Fact]
    public void An_offline_sale_carries_them_through_BatchSync()
    {
        // The ONLY route an offline sale takes to the server. Dropping them here
        // means they existed on the till and nowhere else, forever.
        Assert.Contains("Modifiers = i.Modifiers",
            Read("Commands", "PosOrderCommands", "BatchSync",
                 "BatchSyncPosOrdersCommand.cs"));
    }

    [Fact]
    public void A_refund_reads_like_the_sale_it_reverses()
    {
        Assert.Contains("DocumentItemModifier.Create",
            Read("Commands", "RefundCommands", "ProcessRefundCommand.cs"));
    }

    [Fact]
    public void Both_read_paths_hand_them_back()
    {
        // A device that did not sell the order — or the same one after a
        // reinstall — has no local copy, so the read is the whole story.
        Assert.Contains("dto.Modifiers",
            Read("Queries", "DocumentItemQuery", "GetDocumentItemsByDocumentIdQuery.cs"));
        Assert.Contains("dto.Modifiers",
            Read("Queries", "PosOrderItemQuery", "GetPosOrderItemsByOrderIdQuery.cs"));
    }

    [Fact]
    public void The_snapshot_columns_are_never_looked_up_by_id_on_write()
    {
        // The name and the price are copied at the time of sale and never read
        // back from the catalogue — renaming or repricing an option must not
        // reach backwards into a sale that already happened. A write path that
        // joined ModifierOption to fill Name would break exactly that.
        var checkout = Read("Services", "PosOrderCheckoutService.cs");
        Assert.DoesNotContain("ModifierOptions.FirstOrDefault", checkout);
        Assert.DoesNotContain("Set<ModifierOption>()", checkout);
    }
}
