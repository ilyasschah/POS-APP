using System.Collections.Generic;

namespace Api.Models
{
    /// <summary>One line of the barcode nomenclature as the client sees it.</summary>
    public class BarcodeRuleDto
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        /// <summary>Ascending evaluation order — first match wins.</summary>
        public int Sequence { get; set; }

        /// <summary>Unit | Weighted | Priced | Discounted.</summary>
        public string Type { get; set; } = "Unit";

        /// <summary>Any | Ean13 | UpcA.</summary>
        public string Encoding { get; set; } = "Any";

        public string Pattern { get; set; } = string.Empty;

        public bool IsEnabled { get; set; } = true;
    }

    /// <summary>
    /// The company's complete nomenclature, replacing whatever is stored.
    /// </summary>
    /// <remarks>
    /// Deliberately whole-set rather than per-row CRUD: the editor is a
    /// drag-to-reorder list where a single save can renumber every row, and
    /// sending that as N individual PATCHes would leave the sequence briefly
    /// inconsistent — and permanently so if one call failed. Replacing the set
    /// in one transaction cannot half-apply.
    /// </remarks>
    public class ReplaceBarcodeRulesRequest
    {
        public List<BarcodeRuleDto> Rules { get; set; } = new();
    }
}
