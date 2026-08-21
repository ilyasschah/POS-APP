using Api.Domain;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The conversion half of sell-by-weight. Stock is always held in a category's
/// reference unit, so every one of these guards a way stock could silently drift:
/// a gram sale deducting whole kilograms, a scale's floating noise shaving a
/// fraction off every transaction, or a stale unit id throwing at the till.
/// </summary>
public class UnitOfMeasureTests
{
    private const int Kg = 10;
    private const int G = 11;
    private const int Litre = 20;
    private const int Ml = 21;
    private const int Pieces = 1;

    // ── The user's worked example ────────────────────────────────────────────

    [Fact]
    public void Selling_half_a_kilo_leaves_stock_at_the_expected_figure()
    {
        var stock = 258.000m;

        stock -= UnitOfMeasure.ToReference(0.500m, Kg);

        Assert.Equal(257.500m, stock);
    }

    [Fact]
    public void Selling_a_quarter_kilo_leaves_stock_at_the_expected_figure()
    {
        var stock = 258.000m;

        stock -= UnitOfMeasure.ToReference(0.250m, Kg);

        Assert.Equal(257.750m, stock);
    }

    [Fact]
    public void Selling_one_hundred_grams_deducts_a_tenth_of_a_kilo_not_a_hundred()
    {
        // The single most expensive mistake this layer can make.
        var stock = 258.000m;

        stock -= UnitOfMeasure.ToReference(100m, G);

        Assert.Equal(257.900m, stock);
    }

    // ── Conversion ───────────────────────────────────────────────────────────

    [Theory]
    [InlineData(100, 0.100)]
    [InlineData(250, 0.250)]
    [InlineData(1000, 1.000)]
    [InlineData(1, 0.001)]
    public void Grams_convert_to_kilograms(decimal grams, decimal expectedKg)
        => Assert.Equal(expectedKg, UnitOfMeasure.ToReference(grams, G));

    [Theory]
    [InlineData(500, 0.500)]
    [InlineData(1500, 1.500)]
    public void Millilitres_convert_to_litres(decimal ml, decimal expectedL)
        => Assert.Equal(expectedL, UnitOfMeasure.ToReference(ml, Ml));

    [Fact]
    public void A_reference_unit_converts_to_itself_untouched()
        => Assert.Equal(0.125m, UnitOfMeasure.ToReference(0.125m, Kg));

    [Fact]
    public void Pieces_convert_one_to_one()
        => Assert.Equal(3m, UnitOfMeasure.ToReference(3m, Pieces));

    [Fact]
    public void Conversion_round_trips()
    {
        var backAndForth = UnitOfMeasure.FromReference(UnitOfMeasure.ToReference(250m, G), G);

        Assert.Equal(250m, backAndForth);
    }

    [Fact]
    public void A_negative_delta_converts_symmetrically()
    {
        // Voids and removed order lines hand back negative deltas; an asymmetric
        // rounding rule here would leak stock a fraction at a time.
        Assert.Equal(-0.100m, UnitOfMeasure.ToReference(-100m, G));
    }

    // ── Rounding ─────────────────────────────────────────────────────────────

    [Fact]
    public void A_scales_floating_noise_is_snapped_away()
    {
        // A serial scale reporting 0.4999999996 kg must not shave a fraction
        // off stock on every single sale. Snapped at the storage precision, so
        // the noise dies without the real quantity being touched.
        Assert.Equal(0.500m, UnitOfMeasure.ToReference(0.4999999996m, Kg));
    }

    [Fact]
    public void A_real_quantity_is_not_quantised_to_the_unit_step()
    {
        // The bug this replaces: snapping to the UNIT's rounding turned a
        // deliberate 0.5 on a pcs product into 1, on the line AND in the stock
        // deduction. Conversion snaps at the storage precision instead, so a
        // genuine fraction survives whatever unit it is expressed in.
        Assert.Equal(0.5m, UnitOfMeasure.ToReference(0.5m, Pieces));
        Assert.Equal(88.5m, UnitOfMeasure.ToReference(88.5m, Pieces));
        Assert.Equal(0.1234m, UnitOfMeasure.ToReference(0.1234m, Kg));
    }

    [Fact]
    public void Selling_half_a_unit_deducts_half_a_unit()
    {
        var stock = 88.5m;

        stock -= UnitOfMeasure.ToReference(0.5m, Pieces);

        Assert.Equal(88.0m, stock);
    }

    // ── Catalog integrity ────────────────────────────────────────────────────

    [Fact]
    public void An_unknown_unit_id_falls_back_to_pieces_rather_than_throwing()
    {
        // A product carrying a stale id must still sell.
        Assert.Equal("pcs", UnitOfMeasure.Get(9999).Code);
        Assert.Equal("pcs", UnitOfMeasure.Get(null).Code);
        Assert.Equal(5m, UnitOfMeasure.ToReference(5m, 9999));
    }

    [Fact]
    public void Every_category_has_exactly_one_reference_unit()
    {
        foreach (var group in System.Linq.Enumerable.GroupBy(UnitOfMeasure.All, u => u.Category))
            Assert.Single(System.Linq.Enumerable.Where(group, u => u.IsReference));
    }

    [Fact]
    public void Unit_ids_are_unique()
    {
        var ids = System.Linq.Enumerable.Select(UnitOfMeasure.All, u => u.Id);

        Assert.Equal(UnitOfMeasure.All.Count, System.Linq.Enumerable.Count(System.Linq.Enumerable.Distinct(ids)));
    }

    [Fact]
    public void Conversion_never_crosses_categories()
    {
        // Grams must land in kg, never in litres, whatever the factors happen to be.
        var gramsReference = UnitOfMeasure.ReferenceOf(UnitOfMeasure.Get(G));
        var millilitresReference = UnitOfMeasure.ReferenceOf(UnitOfMeasure.Get(Ml));

        Assert.Equal("kg", gramsReference.Code);
        Assert.Equal("L", millilitresReference.Code);
    }

    // ── Legacy text mapping (mirrors the migration's backfill SQL) ────────────

    [Theory]
    [InlineData("kg", Kg)]
    [InlineData("KG", Kg)]
    [InlineData(" Kg ", Kg)]
    [InlineData("kilogram", Kg)]
    [InlineData("g", G)]
    [InlineData("grams", G)]
    [InlineData("L", Litre)]
    [InlineData("litre", Litre)]
    [InlineData("ml", Ml)]
    [InlineData("pcs", Pieces)]
    public void Known_legacy_unit_text_maps_onto_the_catalog(string text, int expectedId)
        => Assert.Equal(expectedId, UnitOfMeasure.FromLegacyText(text));

    [Theory]
    [InlineData("widget")]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Unrecognised_legacy_unit_text_falls_back_to_pieces(string? text)
        => Assert.Equal(Pieces, UnitOfMeasure.FromLegacyText(text));
}
