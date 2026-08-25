using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>
/// The modifier catalogue — groups, their options, and which products offer them.
/// </summary>
/// <remarks>
/// The three GetAll endpoints are the POS's delta-sync surface and mirror the
/// shape every other cached table uses: <c>companyId</c> plus an optional
/// <c>modifiedAfter</c> watermark, returning rows changed since.
///
/// Validation failures are thrown as <see cref="InvalidOperationException"/> by
/// the service and mapped to a 400 with the message by the existing middleware,
/// so the admin screen can name the offending group.
/// </remarks>
[Route("api/[controller]")]
[ApiController]
public class ModifiersController(ModifierService modifiers) : ControllerBase
{
    /// <summary>Groups changed since <paramref name="modifiedAfter"/>.</summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<List<ModifierGroupDto>>> GetGroups(
        [FromQuery] int companyId,
        [FromQuery] DateTime? modifiedAfter = null,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await modifiers.GetGroupsAsync(companyId, modifiedAfter, ct));
    }

    /// <summary>Options changed since <paramref name="modifiedAfter"/>.</summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<List<ModifierOptionDto>>> GetOptions(
        [FromQuery] int companyId,
        [FromQuery] DateTime? modifiedAfter = null,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await modifiers.GetOptionsAsync(companyId, modifiedAfter, ct));
    }

    /// <summary>Product→group links changed since <paramref name="modifiedAfter"/>.</summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<List<ProductModifierGroupDto>>> GetProductLinks(
        [FromQuery] int companyId,
        [FromQuery] DateTime? modifiedAfter = null,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await modifiers.GetProductLinksAsync(companyId, modifiedAfter, ct));
    }

    /// <summary>
    /// Creates or updates a group together with its complete option list.
    /// </summary>
    /// <remarks>
    /// One call for the whole group because that is what the admin screen edits
    /// and because it makes the write atomic — a group can never land with three
    /// of its six options. Options absent from the payload are deleted.
    /// </remarks>
    [HttpPost("[action]")]
    public async Task<ActionResult<SavedModifierGroupDto>> SaveGroup(
        [FromBody] SaveModifierGroupRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await modifiers.SaveGroupAsync(companyId, request, ct));
    }

    /// <summary>Deletes a group, its options and every product link to it.</summary>
    /// <remarks>
    /// Past sales are unaffected — the line snapshots hold their own copy of the
    /// name and price. Note that a delete only reaches other tills on a FULL
    /// pull; disabling the group is the change that delta-syncs.
    /// </remarks>
    [HttpDelete("[action]")]
    public async Task<IActionResult> DeleteGroup(
        [FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        if (id <= 0) return BadRequest("Modifier group ID is required.");

        var deleted = await modifiers.DeleteGroupAsync(companyId, id, ct);
        return deleted ? NoContent() : NotFound();
    }

    /// <summary>
    /// Replaces the set of groups one product offers. List order becomes the
    /// order the sections appear in at the till.
    /// </summary>
    [HttpPut("[action]")]
    public async Task<ActionResult<List<ProductModifierGroupDto>>> SetProductGroups(
        [FromBody] SetProductModifierGroupsRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await modifiers.SetProductGroupsAsync(companyId, request, ct));
    }
}
