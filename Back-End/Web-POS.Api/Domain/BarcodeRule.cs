using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// What the value embedded in a matched barcode MEANS.
    /// </summary>
    public enum BarcodeRuleType
    {
        /// <summary>Plain product barcode — no embedded value.</summary>
        Unit = 0,

        /// <summary>Embedded value is a quantity in the product's own unit.</summary>
        Weighted = 1,

        /// <summary>Embedded value is a line TOTAL; quantity = value / unit price.</summary>
        Priced = 2,

        /// <summary>Embedded value is a percentage discount for the line.</summary>
        Discounted = 3
    }

    /// <summary>
    /// Symbology the rule is restricted to. <see cref="Any"/> skips length and
    /// check-digit validation entirely.
    /// </summary>
    public enum BarcodeEncoding
    {
        Any = 0,
        Ean13 = 1,
        UpcA = 2
    }

    /// <summary>
    /// One line of the company's barcode nomenclature.
    /// </summary>
    /// <remarks>
    /// Rules are evaluated in <see cref="Sequence"/> order and the FIRST whose
    /// <see cref="Pattern"/> matches wins — which is why the catch-all
    /// <c>.*</c> Unit rule must always sort last. See
    /// <c>Services/BarcodeRuleMatcher.cs</c> for the pattern syntax.
    ///
    /// This replaces the six single-rule <c>Scale.Barcode.*</c> application
    /// properties, which could only ever express one scale format per company.
    /// </remarks>
    [Table("BarcodeRule")]
    public class BarcodeRule
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [Required, MaxLength(100)]
        public string Name { get; private set; } = default!;

        /// <summary>Ascending evaluation order. Ties broken by <see cref="Id"/>.</summary>
        public int Sequence { get; private set; }

        public BarcodeRuleType Type { get; private set; }

        public BarcodeEncoding Encoding { get; private set; }

        /// <summary>
        /// Prefix pattern, e.g. <c>22.....{NNDDD}</c>. Digits match themselves,
        /// <c>.</c> matches any character, and the <c>{N…D…}</c> group marks the
        /// embedded numeric value with <c>D</c> positions as decimals.
        /// </summary>
        [Required, MaxLength(100)]
        public string Pattern { get; private set; } = default!;

        public bool IsEnabled { get; private set; } = true;

        public DateTime LastModified { get; private set; } = DateTime.UtcNow;

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public BarcodeRule() { }

        private BarcodeRule(int companyId, string name, int sequence, BarcodeRuleType type,
                            BarcodeEncoding encoding, string pattern, bool isEnabled)
        {
            CompanyId = companyId;
            Name = name;
            Sequence = sequence;
            Type = type;
            Encoding = encoding;
            Pattern = pattern;
            IsEnabled = isEnabled;
            LastModified = DateTime.UtcNow;
        }

        public static BarcodeRule Create(int companyId, string name, int sequence, BarcodeRuleType type,
                                         BarcodeEncoding encoding, string pattern, bool isEnabled = true)
        {
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Rule name cannot be empty.", nameof(name));
            if (string.IsNullOrWhiteSpace(pattern)) throw new ArgumentException("Pattern cannot be empty.", nameof(pattern));

            return new BarcodeRule(companyId, name.Trim(), sequence, type, encoding, pattern.Trim(), isEnabled);
        }

        public void Update(string? name, int? sequence, BarcodeRuleType? type,
                           BarcodeEncoding? encoding, string? pattern, bool? isEnabled)
        {
            if (!string.IsNullOrWhiteSpace(name)) Name = name.Trim();
            if (sequence.HasValue) Sequence = sequence.Value;
            if (type.HasValue) Type = type.Value;
            if (encoding.HasValue) Encoding = encoding.Value;
            if (!string.IsNullOrWhiteSpace(pattern)) Pattern = pattern.Trim();
            if (isEnabled.HasValue) IsEnabled = isEnabled.Value;

            LastModified = DateTime.UtcNow;
        }
    }
}
