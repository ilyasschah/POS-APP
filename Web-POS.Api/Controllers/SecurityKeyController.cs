using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.SecurityKeyCommands.Add;
using Api.Queries.SecurityKeysQuery.Gett;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SecurityKeyController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<SecurityKeyDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllSecurityKeysQurey()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<SecurityKeyDto>> AddSecurityKey([FromBody] CreateSecurityKeyRequest securityKeyRequest)
        {
            return Ok(await mediator.Send(new AddSecurityKeyCommand(securityKeyRequest)));
        }
    }
}