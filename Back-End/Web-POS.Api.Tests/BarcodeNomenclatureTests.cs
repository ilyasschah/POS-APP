using System.Collections.Generic;
using Api.Domain;
using Api.Services;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The decode half of sell-by-weight. These cover the failures that would be
/// invisible at the till until the money is wrong: a scale label matched by the
/// catch-all rule (item rings at quantity 1), a weight read at the wrong decimal
/// scale (0.350 kg billed as 350), and a product lookup that uses the label's
/// weight digits (every weight looks like a different product).
/// </summary>
public class BarcodeNomenclatureTests
{
    private static BarcodeRule Rule(BarcodeRuleType type, BarcodeEncoding encoding, string pattern, int sequence = 10)
        => BarcodeRule.Create(1, $"{type} rule", sequence, type, encoding, pattern);

    /// <summary>The shipped default nomenclature, in its shipped order.</summary>
    private static List<BarcodeRule> Defaults()
    {
        var rules = new List<BarcodeRule>();
        foreach (var (name, sequence, type, encoding, pattern) in BarcodeRuleSeeder.Defaults)
            rules.Add(BarcodeRule.Create(1, name, sequence, type, encoding, pattern));
        return rules;
    }

    // ── Weight decoding ──────────────────────────────────────────────────────

    [Fact]
    public void Weighted_barcode_decodes_the_embedded_weight_at_three_decimals()
    {
        // 22 + product 10001 + 00350 + check digit. {NNDDD} => 3 decimals.
        var barcode = BarcodeRuleMatcher.WithCheckDigit("221000100350");
        var match = BarcodeRuleMatcher.Match(barcode, Defaults());

        Assert.NotNull(match);
        Assert.Equal(BarcodeRuleType.Weighted, match!.Rule.Type);
        Assert.Equal(0.350m, match.Value);
    }

    [Fact]
    public void Weighted_barcode_blanks_the_weight_digits_from_the_product_key()
    {
        // Two different weights of the SAME product must resolve to one key,
        // otherwise every label on the shelf looks like a new product.
        var light = BarcodeRuleMatcher.WithCheckDigit("221000100350");
        var heavy = BarcodeRuleMatcher.WithCheckDigit("221000102750");

        var a = BarcodeRuleMatcher.Match(light, Defaults());
        var b = BarcodeRuleMatcher.Match(heavy, Defaults());

        Assert.NotNull(a);
        Assert.NotNull(b);
        Assert.Equal(a!.ProductKey, b!.ProductKey);
        Assert.Equal("2210001000000", a.ProductKey);
        Assert.NotEqual(a.Value, b.Value);
    }

    [Fact]
    public void Priced_barcode_decodes_a_total_at_two_decimals()
    {
        // 25 prefix, {NNNDD} => 5 digits, 2 decimals. 01250 => 12.50.
        var barcode = BarcodeRuleMatcher.WithCheckDigit("251000101250");
        var match = BarcodeRuleMatcher.Match(barcode, Defaults());

        Assert.NotNull(match);
        Assert.Equal(BarcodeRuleType.Priced, match!.Rule.Type);
        Assert.Equal(12.50m, match.Value);
    }

    // ── Rule ordering ────────────────────────────────────────────────────────

    [Fact]
    public void First_matching_rule_wins_even_when_a_later_rule_also_matches()
    {
        var rules = new List<BarcodeRule>
        {
            Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Ean13, "22.....{NNDDD}", sequence: 10),
            Rule(BarcodeRuleType.Unit, BarcodeEncoding.Any, ".*", sequence: 20),
        };

        var match = BarcodeRuleMatcher.Match(BarcodeRuleMatcher.WithCheckDigit("221000100350"), rules);

        Assert.Equal(BarcodeRuleType.Weighted, match!.Rule.Type);
    }

    [Fact]
    public void Catch_all_placed_first_swallows_the_scale_label()
    {
        // Documents WHY the seeder pins the Unit rule last: reversed, a weighed
        // item silently rings up as a single unit at full price.
        var rules = new List<BarcodeRule>
        {
            Rule(BarcodeRuleType.Unit, BarcodeEncoding.Any, ".*", sequence: 10),
            Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Ean13, "22.....{NNDDD}", sequence: 20),
        };

        var match = BarcodeRuleMatcher.Match(BarcodeRuleMatcher.WithCheckDigit("221000100350"), rules);

        Assert.Equal(BarcodeRuleType.Unit, match!.Rule.Type);
        Assert.Equal(0m, match.Value);
    }

    [Fact]
    public void Disabled_rules_are_skipped()
    {
        var weighted = Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Ean13, "22.....{NNDDD}", sequence: 10);
        weighted.Update(null, null, null, null, null, isEnabled: false);

        var rules = new List<BarcodeRule> { weighted, Rule(BarcodeRuleType.Unit, BarcodeEncoding.Any, ".*", 20) };
        var match = BarcodeRuleMatcher.Match(BarcodeRuleMatcher.WithCheckDigit("221000100350"), rules);

        Assert.Equal(BarcodeRuleType.Unit, match!.Rule.Type);
    }

    // ── Encoding gates ───────────────────────────────────────────────────────

    [Fact]
    public void Ean13_rule_rejects_a_barcode_with_a_bad_check_digit()
    {
        var rules = new List<BarcodeRule> { Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Ean13, "22.....{NNDDD}") };

        var good = BarcodeRuleMatcher.WithCheckDigit("221000100350");
        var bad = good[..12] + (good[12] == '0' ? '1' : '0');

        Assert.NotNull(BarcodeRuleMatcher.Match(good, rules));
        Assert.Null(BarcodeRuleMatcher.Match(bad, rules));
    }

    [Fact]
    public void Ean13_rule_rejects_a_barcode_of_the_wrong_length()
    {
        var rules = new List<BarcodeRule> { Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Ean13, "22.....{NNDDD}") };

        Assert.Null(BarcodeRuleMatcher.Match("22100010035", rules));
    }

    [Fact]
    public void Any_encoding_skips_length_and_check_digit_validation()
    {
        var rules = new List<BarcodeRule> { Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Any, "22.....{NNDDD}") };

        var match = BarcodeRuleMatcher.Match("221000100350", rules);

        Assert.NotNull(match);
        Assert.Equal(0.350m, match!.Value);
    }

    [Theory]
    [InlineData("4006381333931")] // a real EAN-13
    [InlineData("5901234123457")]
    public void Known_good_ean13_codes_pass_the_check_digit(string barcode)
        => Assert.True(BarcodeRuleMatcher.HasValidCheckDigit(barcode));

    [Fact]
    public void Upca_check_digit_uses_the_same_rule_as_ean13()
        => Assert.True(BarcodeRuleMatcher.HasValidCheckDigit("036000291452"));

    // ── Non-matches ──────────────────────────────────────────────────────────

    [Fact]
    public void A_barcode_matching_no_rule_returns_null()
    {
        var rules = new List<BarcodeRule> { Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Any, "22.....{NNDDD}") };

        Assert.Null(BarcodeRuleMatcher.Match("9912345678901", rules));
    }

    [Fact]
    public void An_empty_nomenclature_returns_null_rather_than_throwing()
        => Assert.Null(BarcodeRuleMatcher.Match("221000100350", new List<BarcodeRule>()));

    [Fact]
    public void A_malformed_placeholder_never_matches()
    {
        // "{NNXDD}" is not a legal placeholder — refusing beats decoding the X
        // as a digit position and billing the wrong weight.
        var rules = new List<BarcodeRule> { Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Any, "22.....{NNXDD}") };

        Assert.Null(BarcodeRuleMatcher.Match("221000100350", rules));
    }

    [Fact]
    public void A_barcode_too_short_for_the_pattern_never_matches()
    {
        var rules = new List<BarcodeRule> { Rule(BarcodeRuleType.Weighted, BarcodeEncoding.Any, "22.....{NNDDD}") };

        Assert.Null(BarcodeRuleMatcher.Match("2210001", rules));
    }

    // ── Legacy settings translation ──────────────────────────────────────────

    [Fact]
    public void Legacy_scale_settings_translate_to_an_equivalent_pattern()
    {
        // The shipped defaults: prefix 21, code length 5, 3 decimals.
        // EAN-13 leaves 13 - 2 - 5 - 1 = 5 value digits.
        var settings = new Dictionary<string, string?>
        {
            ["Scale.Barcode.Enabled"] = "true",
            ["Scale.Barcode.Prefix"] = "21",
            ["Scale.Barcode.CodeLength"] = "5",
            ["Scale.Barcode.DecimalPlaces"] = "3",
            ["Scale.Barcode.PrintsPrice"] = "false",
        };

        var translated = BarcodeRuleSeeder.TranslateLegacyScaleRule(settings);

        Assert.NotNull(translated);
        Assert.Equal(BarcodeRuleType.Weighted, translated!.Value.Type);
        Assert.Equal("21.....{NNDDD}", translated.Value.Pattern);
    }

    [Fact]
    public void Translated_legacy_rule_decodes_the_labels_it_was_derived_from()
    {
        var settings = new Dictionary<string, string?>
        {
            ["Scale.Barcode.Enabled"] = "true",
            ["Scale.Barcode.Prefix"] = "21",
            ["Scale.Barcode.CodeLength"] = "5",
            ["Scale.Barcode.DecimalPlaces"] = "3",
            ["Scale.Barcode.PrintsPrice"] = "false",
        };

        var translated = BarcodeRuleSeeder.TranslateLegacyScaleRule(settings)!.Value;
        var rules = new List<BarcodeRule> { Rule(translated.Type, BarcodeEncoding.Ean13, translated.Pattern) };

        var match = BarcodeRuleMatcher.Match(BarcodeRuleMatcher.WithCheckDigit("211000100500"), rules);

        Assert.NotNull(match);
        Assert.Equal(0.500m, match!.Value);
    }

    [Fact]
    public void Legacy_settings_that_print_a_price_translate_to_a_priced_rule()
    {
        var settings = new Dictionary<string, string?>
        {
            ["Scale.Barcode.Enabled"] = "true",
            ["Scale.Barcode.Prefix"] = "21",
            ["Scale.Barcode.CodeLength"] = "5",
            ["Scale.Barcode.DecimalPlaces"] = "2",
            ["Scale.Barcode.PrintsPrice"] = "true",
        };

        var translated = BarcodeRuleSeeder.TranslateLegacyScaleRule(settings);

        Assert.Equal(BarcodeRuleType.Priced, translated!.Value.Type);
        Assert.Equal("21.....{NNNDD}", translated.Value.Pattern);
    }

    [Fact]
    public void Legacy_translation_is_skipped_when_scale_parsing_was_never_enabled()
    {
        var settings = new Dictionary<string, string?> { ["Scale.Barcode.Enabled"] = "false" };

        Assert.Null(BarcodeRuleSeeder.TranslateLegacyScaleRule(settings));
    }

    // ── Save-time validation ─────────────────────────────────────────────────

    [Fact]
    public void A_weighted_rule_without_a_placeholder_is_rejected()
    {
        // It would match, contribute a weight of zero, and ring the item up free.
        var error = BarcodeRuleService.ValidatePattern("22.....", BarcodeRuleType.Weighted);

        Assert.NotNull(error);
    }

    [Fact]
    public void A_unit_rule_with_a_placeholder_is_rejected()
        => Assert.NotNull(BarcodeRuleService.ValidatePattern("22{NNDDD}", BarcodeRuleType.Unit));

    [Fact]
    public void A_unit_rule_without_a_placeholder_is_accepted()
        => Assert.Null(BarcodeRuleService.ValidatePattern(".*", BarcodeRuleType.Unit));

    [Theory]
    [InlineData("22.....{NNDDD")]
    [InlineData("22.....{}")]
    [InlineData("22.....{NNXDD}")]
    [InlineData("22{NN}.{DD}")]
    [InlineData("")]
    public void Malformed_patterns_are_rejected_at_save_time(string pattern)
        => Assert.NotNull(BarcodeRuleService.ValidatePattern(pattern, BarcodeRuleType.Weighted));
}
