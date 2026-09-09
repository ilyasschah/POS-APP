using Api.Domain;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Per-product pack sizes: what a "box" of THIS product actually contains.
///
/// <para>Before <c>Product.PackSize</c>, box and pack carried a hardcoded 1/12 and
/// 1/6, so a box of anything was 12 — a 24-can box of soda restocked 12 cans and
/// left the other 12 unaccounted for on every single sale and refund.</para>
///
/// <para>The rule these pin, in one line: <b>a null pack size must behave exactly
/// like the old hardcoded factor.</b> That is what makes the column safe to add to
/// a catalogue that is already selling — the migration adds a NULL to every row,
/// and NULL has to mean "carry on as before", not "this product is now 1 piece".</para>
/// </summary>
public class ProductPackSizeTests
{
    private const int Pieces = UnitOfMeasure.PiecesId;
    private const int Dozen = UnitOfMeasure.DozenId;
    private const int Box = UnitOfMeasure.BoxId;
    private const int Pack = UnitOfMeasure.PackId;
    private const int Kg = UnitOfMeasure.KilogramId;
    private const int G = 11;

    // ── The reason the column exists ─────────────────────────────────────────

    [Fact]
    public void A_box_of_twenty_four_moves_twenty_four_pieces_of_stock()
    {
        var stock = 100m;

        stock -= UnitOfMeasure.ToReference(2m, Box, packSize: 24m);

        Assert.Equal(52m, stock);
    }

    [Fact]
    public void The_same_two_boxes_moved_only_twenty_four_before_the_column_existed()
    {
        // Not a curiosity — this is the behaviour every existing row still has,
        // and the bug the feature was asked for.
        var stock = 100m;

        stock -= UnitOfMeasure.ToReference(2m, Box, packSize: null);

        Assert.Equal(76m, stock);
    }

    // ── Back-compatibility: null means the nominal factor ────────────────────

    [Theory]
    [InlineData(Box, 12)]   // 1/12
    [InlineData(Pack, 6)]   // 1/6
    public void A_null_pack_size_falls_back_to_the_catalog_nominal(int uomId, int nominal)
        => Assert.Equal(nominal, UnitOfMeasure.ToReference(1m, uomId, null));

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    public void A_zero_or_negative_pack_size_falls_back_rather_than_dividing_by_it(decimal packSize)
    {
        // A zero would otherwise be a division by nothing, and a negative one
        // would ADD stock on a sale.
        Assert.Equal(12m, UnitOfMeasure.ToReference(1m, Box, packSize));
        Assert.Null(UnitOfMeasure.NormalisePackSize(Box, packSize));
    }

    // ── Which units listen to it ─────────────────────────────────────────────

    [Fact]
    public void A_dozen_is_twelve_whatever_the_product_claims()
    {
        // Deliberately not overridable: a dozen is a definition, not a packaging
        // choice, and a product claiming otherwise would be lying on a receipt.
        Assert.False(UnitOfMeasure.IsPackSized(Dozen));
        Assert.Equal(12m, UnitOfMeasure.ToReference(1m, Dozen, packSize: 10m));
    }

    [Theory]
    [InlineData(Kg)]
    [InlineData(G)]
    [InlineData(Pieces)]
    public void A_physical_unit_ignores_a_pack_size_entirely(int uomId)
    {
        Assert.False(UnitOfMeasure.IsPackSized(uomId));
        Assert.Equal(
            UnitOfMeasure.ToReference(500m, uomId, null),
            UnitOfMeasure.ToReference(500m, uomId, packSize: 24m));
    }

    // ── The two directions have to agree ─────────────────────────────────────

    [Theory]
    [InlineData(24)]
    [InlineData(6)]
    [InlineData(1)]
    public void Converting_out_and_back_returns_the_same_quantity(decimal packSize)
    {
        var boxes = 3m;

        var pieces = UnitOfMeasure.ToReference(boxes, Box, packSize);

        Assert.Equal(boxes, UnitOfMeasure.FromReference(pieces, Box, packSize));
    }

    [Fact]
    public void Stock_on_hand_reads_back_as_the_number_of_boxes_it_makes()
    {
        // 120 pieces is 5 boxes of 24 — and was 10 boxes when the box was 12.
        // Changing a pack size never rewrites stock; it restates what the stock
        // already on hand adds up to.
        Assert.Equal(5m, UnitOfMeasure.FromReference(120m, Box, packSize: 24m));
        Assert.Equal(10m, UnitOfMeasure.FromReference(120m, Box, null));
    }

    [Fact]
    public void A_pack_size_of_one_makes_a_box_a_single_piece()
    {
        Assert.Equal(1m, UnitOfMeasure.EffectiveFactor(Box, 1m));
        Assert.Equal(7m, UnitOfMeasure.ToReference(7m, Box, packSize: 1m));
    }

    // ── What gets stored ─────────────────────────────────────────────────────

    [Fact]
    public void A_pack_size_is_only_kept_on_a_unit_that_can_use_one()
    {
        // Kept: the admin said 24 to a box.
        Assert.Equal(24m, UnitOfMeasure.NormalisePackSize(Box, 24m));
        Assert.Equal(4m, UnitOfMeasure.NormalisePackSize(Pack, 4m));

        // Dropped: it would sit on the row waiting to be believed if the unit
        // ever moved back to box.
        Assert.Null(UnitOfMeasure.NormalisePackSize(Kg, 24m));
        Assert.Null(UnitOfMeasure.NormalisePackSize(Pieces, 24m));
        Assert.Null(UnitOfMeasure.NormalisePackSize(Dozen, 10m));
    }

    [Fact]
    public void Fractional_pack_sizes_survive_the_storage_precision()
    {
        // decimal(18,4) on both sides; 2.5 to a pack is odd but not the
        // conversion's business to refuse.
        Assert.Equal(5m, UnitOfMeasure.ToReference(2m, Pack, packSize: 2.5m));
    }
}
