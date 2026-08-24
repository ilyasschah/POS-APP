using System;
using System.Collections.Generic;

namespace Api.Models
{
    /// <summary>Wire shape of a <see cref="Api.Domain.ModifierGroup"/>.</summary>
    /// <remarks>
    /// Flat, with no nested options, because the POS caches groups and options as
    /// two separate Drift tables and delta-syncs each on its own watermark.
    /// Nesting would mean re-sending every option whenever a group's name changed.
    /// The admin screen composes them client-side.
    /// </remarks>
    public class ModifierGroupDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; } = string.Empty;
        public int MinSelections { get; set; }
        public int MaxSelections { get; set; } = 1;
        public bool AllowsFreeText { get; set; }
        public int Rank { get; set; }
        public bool IsEnabled { get; set; } = true;
        public DateTime LastModified { get; set; }
    }

    public class ModifierOptionDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int ModifierGroupId { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal AdditionalPrice { get; set; }
        public int Rank { get; set; }
        public bool IsEnabled { get; set; } = true;
        public DateTime LastModified { get; set; }
    }

    public class ProductModifierGroupDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int ProductId { get; set; }
        public int ModifierGroupId { get; set; }
        public int Rank { get; set; }
        public DateTime LastModified { get; set; }
    }

    /// <summary>
    /// What <c>SaveGroup</c> hands back: the group AND its options, with the
    /// ids the server actually assigned.
    /// </summary>
    /// <remarks>
    /// 🚨 The options are returned for a reason that cost real data. The client
    /// writes new options with temporary NEGATIVE ids while offline; the server
    /// then assigns real ones. Returning only the group left the client with no
    /// way to know which local row became which server row, so it kept its
    /// temporary rows and the next delta pull added the real ones ALONGSIDE
    /// them — every choice appeared twice, permanently, because the group was
    /// synced by then and never re-entered the push queue.
    ///
    /// With the saved list in the response the client replaces the group's
    /// options outright and the temporary rows cannot survive.
    /// </remarks>
    public class SavedModifierGroupDto : ModifierGroupDto
    {
        public List<ModifierOptionDto> Options { get; set; } = new();
    }

    /// <summary>
    /// Saves a group AND its full option list in one call.
    /// </summary>
    /// <remarks>
    /// The unit is the whole group because that is the unit the admin screen
    /// edits: a "Toppings" group with six options is one form and one Save. It
    /// is also what makes the write safe — options are reconciled against this
    /// list inside a transaction, so a group can never end up half-saved with
    /// three of its six choices.
    ///
    /// <see cref="ModifierOptionDto.Rank"/> from the client is ignored in favour
    /// of list position, the same rule <c>BarcodeRuleService.ReplaceAllAsync</c>
    /// follows: the editor reorders by drag, and trusting position removes any
    /// chance of two options claiming the same rank.
    /// </remarks>
    public class SaveModifierGroupRequest
    {
        /// <summary>0 or negative creates; a real id updates in place.</summary>
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;
        public int MinSelections { get; set; }
        public int MaxSelections { get; set; } = 1;
        public bool AllowsFreeText { get; set; }
        public int Rank { get; set; }
        public bool IsEnabled { get; set; } = true;

        /// <summary>
        /// The group's complete option list. Options absent from it are deleted,
        /// so this is a replace and not a merge.
        /// </summary>
        public List<SaveModifierOptionRequest> Options { get; set; } = new();
    }

    public class SaveModifierOptionRequest
    {
        /// <summary>0 or negative creates; a real id updates in place.</summary>
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;
        public decimal AdditionalPrice { get; set; }
        public bool IsEnabled { get; set; } = true;
    }

    /// <summary>Replaces the whole set of groups one product offers.</summary>
    /// <remarks>
    /// Order in <see cref="ModifierGroupIds"/> IS the order the sections appear
    /// in the cashier's customise sheet.
    /// </remarks>
    public class SetProductModifierGroupsRequest
    {
        public int ProductId { get; set; }
        public List<int> ModifierGroupIds { get; set; } = new();
    }
}
