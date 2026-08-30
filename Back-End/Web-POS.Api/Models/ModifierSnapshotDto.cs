namespace Api.Models
{
    /// <summary>
    /// One chosen modifier option, as the client recorded it at the moment of
    /// sale. The wire shape behind both <see cref="Api.Domain.PosOrderItemModifier"/>
    /// and <see cref="Api.Domain.DocumentItemModifier"/>.
    /// </summary>
    /// <remarks>
    /// 🚨 <b>The client is the source of these values, deliberately.</b> They are
    /// SNAPSHOTS: the name and the price as they read when the cashier tapped
    /// them, which is not necessarily what the catalogue says now, and on an
    /// offline till may be a catalogue this server has not synced yet. Looking
    /// <see cref="ModifierOptionId"/> up and using today's row would silently
    /// rewrite what a past sale says it sold — the exact thing the snapshot
    /// design exists to prevent.
    ///
    /// The surcharge is ALSO already inside the line's price. These rows are the
    /// breakdown and the reporting handle, never an amount to add to a total.
    /// </remarks>
    public class ModifierSnapshotDto
    {
        /// Catalogue option id, for `GROUP BY ModifierOptionId` reporting. Null
        /// is legitimate: an option deleted since the sale, or a line that
        /// predates the catalogue.
        public int? ModifierOptionId { get; set; }

        /// Group name as it read at the time of sale ("Toppings").
        public string? GroupName { get; set; }

        /// Option name as it read at the time of sale ("Extra Cheese").
        public string Name { get; set; } = string.Empty;

        /// Surcharge as it was priced at the time of sale.
        public decimal AdditionalPrice { get; set; }

        /// Ascending display order — the order the cashier was asked.
        public int Rank { get; set; }
    }
}
