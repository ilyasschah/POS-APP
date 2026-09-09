using System.Collections.Generic;
using System.Linq;

namespace Api.Domain
{
    /// <summary>
    /// The category a unit belongs to. Conversion is only ever legal BETWEEN
    /// units of the same category — grams convert to kilograms, never to litres.
    /// </summary>
    public enum UomCategory
    {
        Unit = 1,
        Weight = 2,
        Volume = 3,
        Length = 4
    }

    /// <summary>
    /// One entry of the hardcoded unit catalog.
    /// </summary>
    /// <remarks>
    /// Deliberately NOT a table. The catalog is fixed, tiny, and must agree
    /// byte-for-byte with the Dart mirror in <c>lib/uom/unit_of_measure.dart</c>;
    /// a table would let the two drift and would make <c>Product.UomId</c> a
    /// foreign key that every deployment has to seed identically anyway.
    ///
    /// <see cref="Factor"/> is how many of THIS unit make one reference unit of
    /// the category — g has factor 1000 because 1000 g are one kg. Converting a
    /// quantity to the reference unit is therefore a DIVISION by the factor.
    /// </remarks>
    public sealed class UnitOfMeasure
    {
        public int Id { get; }
        public string Code { get; }
        public UomCategory Category { get; }
        public decimal Factor { get; }

        /// <summary>
        /// Smallest meaningful step for this unit (0.001 for kg, 1 for g).
        /// Quantities are snapped to it so a scale's floating noise cannot
        /// write 0.4999999996 kg into stock.
        /// </summary>
        public decimal Rounding { get; }

        /// <summary>Decimal places implied by <see cref="Rounding"/>, for display.</summary>
        public int Digits { get; }

        /// <summary>True for the one unit its category is stored in.</summary>
        public bool IsReference => Factor == 1m;

        private UnitOfMeasure(int id, string code, UomCategory category, decimal factor, decimal rounding, int digits)
        {
            Id = id;
            Code = code;
            Category = category;
            Factor = factor;
            Rounding = rounding;
            Digits = digits;
        }

        // ── The catalog ──────────────────────────────────────────────────────
        // Ids are permanent: they are written into Product.UomId. Never reuse or
        // renumber one, and add new units with fresh ids at the end of a block.

        public const int PiecesId = 1;
        public const int DozenId = 2;
        public const int BoxId = 3;
        public const int PackId = 4;
        public const int KilogramId = 10;
        public const int LitreId = 20;
        public const int MetreId = 30;

        public static readonly IReadOnlyList<UnitOfMeasure> All = new List<UnitOfMeasure>
        {
            // Unit — reference: pcs
            new(PiecesId, "pcs",   UomCategory.Unit,   1m,        1m,     0),
            new(DozenId,  "dozen", UomCategory.Unit,   1m / 12m,  1m,     0),
            // 🚨 box and pack carry a NOMINAL factor only. It is the fallback for a
            // product that has not stated its own Product.PackSize — see
            // IsPackSized / EffectiveFactor. A dozen is 12 by definition and is
            // deliberately NOT overridable.
            new(BoxId,    "box",   UomCategory.Unit,   1m / 12m,  1m,     0),
            new(PackId,   "pack",  UomCategory.Unit,   1m / 6m,   1m,     0),

            // Weight — reference: kg
            new(KilogramId, "kg",  UomCategory.Weight, 1m,        0.001m, 3),
            new(11,         "g",   UomCategory.Weight, 1000m,     1m,     0),
            new(12,         "lb",  UomCategory.Weight, 2.20462m,  0.01m,  2),

            // Volume — reference: L
            new(LitreId, "L",      UomCategory.Volume, 1m,        0.001m, 3),
            new(21,      "mL",     UomCategory.Volume, 1000m,     1m,     0),

            // Length — reference: m
            new(MetreId, "m",      UomCategory.Length, 1m,        0.001m, 3),
            new(31,      "cm",     UomCategory.Length, 100m,      1m,     0),
        };

        private static readonly Dictionary<int, UnitOfMeasure> ById =
            All.ToDictionary(u => u.Id);

        private static readonly Dictionary<UomCategory, UnitOfMeasure> ReferenceByCategory =
            All.Where(u => u.IsReference).ToDictionary(u => u.Category);

        /// <summary>
        /// The unit with <paramref name="id"/>, or pieces when the id is unknown
        /// or null. Never throws: a product carrying a stale id must still sell.
        /// </summary>
        public static UnitOfMeasure Get(int? id)
            => id.HasValue && ById.TryGetValue(id.Value, out var u) ? u : ById[PiecesId];

        /// <summary>The unit <paramref name="unit"/>'s category keeps its stock in.</summary>
        public static UnitOfMeasure ReferenceOf(UnitOfMeasure unit)
            => ReferenceByCategory[unit.Category];

        /// <summary>
        /// The units whose catalog <see cref="Factor"/> is only a NOMINAL default,
        /// overridable per product by <c>Product.PackSize</c>: a box of tuna and a
        /// box of water are not both 12.
        /// </summary>
        /// <remarks>
        /// Deliberately just box and pack. <c>dozen</c> is 12 by definition — making
        /// it overridable would let a product claim a dozen is 10 — and every other
        /// unit is a fixed physical conversion (1000 g in a kg, whatever the product).
        /// </remarks>
        public static bool IsPackSized(int? uomId) => uomId is BoxId or PackId;

        /// <summary>
        /// The pack size worth storing for a product on the unit
        /// <paramref name="uomId"/>: only a positive one, and only on a
        /// pack-sized unit. Everything else is NULL — "use the nominal factor".
        /// </summary>
        /// <remarks>
        /// Clearing rather than rejecting is deliberate. A size left over from a
        /// unit the admin has since changed (24 to a box, then switched to kg)
        /// would otherwise sit on the row waiting to be believed the next time
        /// somebody picks box again. A zero is the same mistake made faster: it
        /// would divide every conversion by nothing.
        /// </remarks>
        public static decimal? NormalisePackSize(int? uomId, decimal? packSize)
            => IsPackSized(uomId) && packSize is > 0m ? packSize : null;

        /// <summary>
        /// How many of the unit with <paramref name="uomId"/> make one reference
        /// unit, once the product's own <paramref name="packSize"/> is applied.
        /// </summary>
        /// <remarks>
        /// <paramref name="packSize"/> is stated the way a human says it — "24 to a
        /// box" — so the factor is its RECIPROCAL, matching the catalog's 1/12.
        /// A null, zero or negative pack size falls back to the nominal factor, which
        /// is what every product carried before the column existed; that fallback is
        /// what makes the column safe to add to a live catalogue.
        /// </remarks>
        public static decimal EffectiveFactor(int? uomId, decimal? packSize)
        {
            var unit = Get(uomId);
            if (!IsPackSized(unit.Id) || packSize is not > 0m) return unit.Factor;
            return 1m / packSize.Value;
        }

        /// <summary>
        /// Converts <paramref name="quantity"/>, expressed in the unit with
        /// <paramref name="uomId"/>, into that category's reference unit — the
        /// only unit the Stock table ever holds.
        /// </summary>
        /// <param name="packSize">
        /// The product's own <c>PackSize</c>. Required rather than optional on
        /// purpose: it is only ever read from the product being moved, and a default
        /// here would let a call site silently restock a 24-box as 12 pieces.
        /// </param>
        /// <example>100 g with uomId 11 → 0.100 (kg); 2 boxes of 24 → 48 (pcs).</example>
        public static decimal ToReference(decimal quantity, int? uomId, decimal? packSize)
        {
            var factor = EffectiveFactor(uomId, packSize);
            var converted = factor == 1m ? quantity : quantity / factor;
            return SnapToStorage(converted);
        }

        /// <summary>
        /// The inverse of <see cref="ToReference"/>: takes a reference-unit
        /// quantity and expresses it in the unit with <paramref name="uomId"/>.
        /// Used to show stock in the unit a product is actually sold in.
        /// </summary>
        public static decimal FromReference(decimal referenceQuantity, int? uomId, decimal? packSize)
        {
            var factor = EffectiveFactor(uomId, packSize);
            var converted = factor == 1m ? referenceQuantity : referenceQuantity * factor;
            return SnapToStorage(converted);
        }

        /// <summary>
        /// The precision every quantity column actually stores —
        /// <c>decimal(18,4)</c>. 0.0001 kg is a tenth of a gram.
        /// </summary>
        public const decimal QuantityStorageStep = 0.0001m;

        /// <summary>
        /// Kills rounding error without altering the number.
        /// </summary>
        /// <remarks>
        /// Snapping to the UNIT's rounding was wrong here and quietly
        /// destructive: on a <c>pcs</c> product (rounding 1) it turned a
        /// deliberate 0.5 into 1, both on the line and in the stock deduction.
        /// The unit's rounding is a display and scale-reading concern; what
        /// conversion needs is only to stop 0.4999999996 reaching the database,
        /// so it snaps at the storage precision instead.
        /// </remarks>
        public static decimal SnapToStorage(decimal value) => Snap(value, QuantityStorageStep);

        /// <summary>
        /// Rounds to the nearest multiple of <paramref name="rounding"/>.
        /// A scale reporting 0.4999999996 kg must land on 0.500, not shave a
        /// gram off stock on every sale.
        /// </summary>
        public static decimal Snap(decimal value, decimal rounding)
        {
            if (rounding <= 0m) return value;
            return decimal.Round(value / rounding, 0, System.MidpointRounding.AwayFromZero) * rounding;
        }

        /// <summary>
        /// Best-effort match of the legacy free-text <c>Product.MeasurementUnit</c>
        /// onto a catalog id, for the one-time backfill. Anything unrecognised
        /// is pieces — the safe default, since it converts 1:1 and cannot move
        /// existing stock numbers.
        /// </summary>
        public static int FromLegacyText(string? text)
        {
            if (string.IsNullOrWhiteSpace(text)) return PiecesId;

            return text.Trim().ToLowerInvariant() switch
            {
                "kg" or "kgs" or "kilo" or "kilos" or "kilogram" or "kilograms" => KilogramId,
                "g" or "gr" or "gm" or "gram" or "grams" => 11,
                "lb" or "lbs" or "pound" or "pounds" => 12,
                "l" or "lt" or "ltr" or "litre" or "litres" or "liter" or "liters" => LitreId,
                "ml" or "millilitre" or "millilitres" or "milliliter" or "milliliters" => 21,
                "m" or "mtr" or "meter" or "meters" or "metre" or "metres" => MetreId,
                "cm" or "centimeter" or "centimeters" or "centimetre" or "centimetres" => 31,
                "dozen" or "dz" or "doz" => 2,
                "box" or "bx" or "carton" => 3,
                "pack" or "pk" or "packet" => 4,
                _ => PiecesId,
            };
        }
    }
}
