using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Api.Domain;

namespace Api.Services
{
    /// <summary>Outcome of matching a scanned barcode against a nomenclature.</summary>
    public sealed class BarcodeMatch
    {
        /// <summary>The rule that claimed the barcode.</summary>
        public BarcodeRule Rule { get; init; } = default!;

        /// <summary>
        /// The barcode with the embedded-value digits blanked back to zeros —
        /// this is what the product's stored barcode must equal. A scale prints a
        /// different barcode for every weight, so the digits carrying the weight
        /// cannot participate in the product lookup.
        /// </summary>
        public string ProductKey { get; init; } = default!;

        /// <summary>
        /// The decoded embedded number, already scaled by its decimal positions.
        /// Zero for <see cref="BarcodeRuleType.Unit"/> rules.
        /// </summary>
        public decimal Value { get; init; }
    }

    /// <summary>
    /// Implements the Odoo-style barcode nomenclature: an ordered rule list where
    /// the first pattern to match a barcode's PREFIX wins.
    /// </summary>
    /// <remarks>
    /// Pattern syntax:
    /// <list type="bullet">
    /// <item>a digit matches itself</item>
    /// <item>a dot matches any single character</item>
    /// <item>a brace group marks the embedded numeric value. Each N or D inside
    /// is one digit position and D positions are decimals, so {NNDDD} is five
    /// digits with three decimals and "00350" decodes to 0.350.</item>
    /// </list>
    /// Matching is prefix-based: the pattern "22" matches any barcode starting
    /// with 22.
    /// </remarks>
    public static class BarcodeRuleMatcher
    {
        /// <summary>
        /// Returns the first enabled rule whose pattern matches
        /// <paramref name="barcode"/>, or null when none does.
        /// </summary>
        public static BarcodeMatch? Match(string? barcode, IEnumerable<BarcodeRule> rules)
        {
            if (string.IsNullOrWhiteSpace(barcode)) return null;

            var code = barcode.Trim();

            foreach (var rule in rules.Where(r => r.IsEnabled)
                                      .OrderBy(r => r.Sequence)
                                      .ThenBy(r => r.Id))
            {
                var match = TryMatch(code, rule);
                if (match != null) return match;
            }

            return null;
        }

        /// <summary>
        /// Tests one rule. Split out so a settings screen can preview a pattern
        /// against a sample barcode without building a whole nomenclature.
        /// </summary>
        public static BarcodeMatch? TryMatch(string barcode, BarcodeRule rule)
        {
            if (!EncodingAccepts(barcode, rule.Encoding)) return null;

            var pattern = rule.Pattern;

            // A bare ".*" is the conventional catch-all. Short-circuiting keeps it
            // from walking the whole barcode one character at a time.
            if (pattern == ".*")
                return new BarcodeMatch { Rule = rule, ProductKey = barcode, Value = 0m };

            var open = pattern.IndexOf('{');
            var close = open >= 0 ? pattern.IndexOf('}', open + 1) : -1;

            // No embedded value: the pattern is a plain prefix test.
            if (open < 0 || close < 0)
            {
                return PrefixMatches(barcode, pattern, 0)
                    ? new BarcodeMatch { Rule = rule, ProductKey = barcode, Value = 0m }
                    : null;
            }

            var head = pattern.Substring(0, open);
            var placeholder = pattern.Substring(open + 1, close - open - 1);
            var tail = pattern.Substring(close + 1);

            // Every N/D is one digit position. Anything else inside the braces is a
            // malformed pattern — refuse rather than silently mis-decoding.
            var decimals = placeholder.Count(c => c is 'D' or 'd');
            var width = placeholder.Count(c => c is 'N' or 'n' or 'D' or 'd');
            if (width == 0 || width != placeholder.Length) return null;

            // A trailing "*" means "and anything after", so it is not position
            // checked. Everything else in the tail is.
            var tailPattern = tail.Replace("*", string.Empty);

            // The barcode must be long enough to hold the head, the value, and
            // whatever the tail demands.
            if (barcode.Length < head.Length + width + tailPattern.Length) return null;

            if (!PrefixMatches(barcode, head, 0)) return null;

            var digits = barcode.Substring(head.Length, width);
            if (!digits.All(char.IsDigit)) return null;

            if (!PrefixMatches(barcode, tailPattern, head.Length + width)) return null;

            var raw = decimal.Parse(digits, CultureInfo.InvariantCulture);
            var value = raw / Pow10(decimals);

            // Blank the value digits so every weight of one product resolves to the
            // same lookup key — this is exactly why Odoo tells you to store the
            // product's barcode with those positions as zeros.
            var key = barcode.Substring(0, head.Length)
                    + new string('0', width)
                    + barcode.Substring(head.Length + width);

            // The scale recomputes the trailing check digit for every weight, so
            // the tail copied above still carries the ORIGINAL label's digit —
            // which would make 350 g and 2.750 kg of one product produce two
            // different keys and fail every lookup but the first. Recomputing it
            // over the zeroed body is what makes the key canonical.
            if (rule.Encoding is BarcodeEncoding.Ean13 or BarcodeEncoding.UpcA)
                key = WithCheckDigit(key.Substring(0, key.Length - 1));

            return new BarcodeMatch { Rule = rule, ProductKey = key, Value = value };
        }

        /// <summary>
        /// Compares <paramref name="pattern"/> against <paramref name="barcode"/>
        /// starting at <paramref name="offset"/>, treating '.' as a wildcard.
        /// </summary>
        private static bool PrefixMatches(string barcode, string pattern, int offset)
        {
            if (pattern.Length == 0) return true;
            if (barcode.Length < offset + pattern.Length) return false;

            for (var i = 0; i < pattern.Length; i++)
            {
                var p = pattern[i];
                if (p == '.') continue;
                if (barcode[offset + i] != p) return false;
            }

            return true;
        }

        /// <summary>
        /// Length and check-digit gate for the fixed symbologies.
        /// <see cref="BarcodeEncoding.Any"/> accepts everything, which is what
        /// internal and PLU codes need.
        /// </summary>
        private static bool EncodingAccepts(string barcode, BarcodeEncoding encoding) => encoding switch
        {
            BarcodeEncoding.Ean13 => barcode.Length == 13 && barcode.All(char.IsDigit) && HasValidCheckDigit(barcode),
            BarcodeEncoding.UpcA => barcode.Length == 12 && barcode.All(char.IsDigit) && HasValidCheckDigit(barcode),
            _ => true
        };

        /// <summary>
        /// Modulo-10 check digit shared by EAN-13 and UPC-A. Weights alternate 3
        /// and 1 counting from the RIGHT, which makes one rule correct for both
        /// lengths without special-casing.
        /// </summary>
        public static bool HasValidCheckDigit(string barcode)
        {
            if (barcode.Length < 2 || !barcode.All(char.IsDigit)) return false;

            var body = barcode.Substring(0, barcode.Length - 1);
            return WithCheckDigit(body) == barcode;
        }

        /// <summary>
        /// Appends the modulo-10 check digit to a barcode body. A scale rewrites
        /// that digit for every weight, so blanking the value digits invalidates
        /// it — callers that want a printable barcode back use this.
        /// </summary>
        public static string WithCheckDigit(string body)
        {
            var sum = 0;
            for (var i = body.Length - 1; i >= 0; i--)
            {
                var digit = body[i] - '0';
                var positionFromRight = body.Length - i; // 1, 2, 3, …
                sum += positionFromRight % 2 == 1 ? digit * 3 : digit;
            }

            return body + ((10 - sum % 10) % 10);
        }

        private static decimal Pow10(int exponent)
        {
            var result = 1m;
            for (var i = 0; i < exponent; i++) result *= 10m;
            return result;
        }
    }
}
