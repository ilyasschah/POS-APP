using Api.Commands.SecurityKeyCommands;
using Api.Models;
using Api.Queries.SecurityKeyQueries;
using Api.Queries.SecurityKeysQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SecurityKeysController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<SecurityKeyDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllSecurityKeysQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<SecurityKeyDto>> GetByName([FromQuery] string name, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (string.IsNullOrWhiteSpace(name)) return BadRequest("Name is required");

            var result = await mediator.Send(new GetSecurityKeyByNameQuery { Name = name, CompanyId = companyId });
            if (result == null) return NotFound();

            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> Update([FromBody] UpdateSecurityKeyRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var command = new UpdateSecurityKeyCommand { Request = request, CompanyId = companyId };
            var success = await mediator.Send(command);

            if (!success) return NotFound();

            return Ok(new { Message = "Security key updated successfully" });
        }
    }
}