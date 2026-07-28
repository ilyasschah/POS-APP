using Api.Commands.SecurityKeyCommands.Add;
using Api.Models;
using Api.Queries.SecurityKeysQuery;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SecurityKeysController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<SecurityKeyDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllSecurityKeysQuery { CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<SecurityKeyDto>> GetByName([FromQuery] string name, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (string.IsNullOrWhiteSpace(name)) return BadRequest("Name is required");

            var result = await mediator.Send(new GetSecurityKeyByNameQuery { Name = name, CompanyId = companyId }, ct);
            if (result == null) return NotFound();

            return Ok(result);
        }

        // Manager-only: this endpoint configures the RBAC levels themselves, so a
        // cashier must never be able to lower a key to Cashier-accessible.
        [Authorize(Policy = "ManagerOnly")]
        [HttpPatch("[action]")]
        public async Task<ActionResult> Update([FromBody] UpdateSecurityKeyRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var command = new UpdateSecurityKeyCommand { Request = request, CompanyId = companyId };
            var success = await mediator.Send(command, ct);

            if (!success) return NotFound();

            return Ok(new { Message = "Security key updated successfully" });
        }
    }
}