using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>
/// The company's barcode nomenclature — the ordered rule list that decides how a
/// scanned barcode is read (plain product, weight, price, or discount).
/// </summary>
/// <remarks>
/// Validation failures are thrown as <see cref="System.InvalidOperationException"/>
/// by the service and mapped to a 400 with the message by the existing
/// middleware, so the settings screen can show the offending rule by name.
/// </remarks>
[Route("api/[controller]")]
[ApiController]
public class BarcodeRulesController(BarcodeRuleService rules) : ControllerBase
{
    /// <summary>The company's rules, already in evaluation order.</summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<List<BarcodeRuleDto>>> GetAll(
        [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await rules.GetAllAsync(companyId, ct));
    }

    /// <summary>
    /// Replaces the whole rule set. Order in the payload IS the evaluation order.
    /// </summary>
    [HttpPut("[action]")]
    public async Task<ActionResult<List<BarcodeRuleDto>>> ReplaceAll(
        [FromBody] ReplaceBarcodeRulesRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await rules.ReplaceAllAsync(companyId, request.Rules, ct));
    }
}
