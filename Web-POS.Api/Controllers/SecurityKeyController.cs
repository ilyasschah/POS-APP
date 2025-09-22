using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.SecurityKeyCommands.Add;
using Products.Api.Models;
using Products.Api.Queries.SecurityKeysQuery.Gett;

namespace Products.Api.Controllers
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