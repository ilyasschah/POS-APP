using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.VoidReasonCommads.Add;
using Api.Commands.VoidReasonCommads.Delete;
using Api.Commands.VoidReasonCommads.Update;
using Api.Queries.VoidReasonQuery;
using System.Collections.Generic;
using System.Threading.Tasks;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class VoidReasonsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<VoidReasonDto>>> GetAll([FromQuery] int? companyId = null)
        {
            var result = await mediator.Send(new GetAllVoidReasonsQuery { CompanyId = companyId });
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<VoidReasonDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetVoidReasonByIdQuery { Id = id });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<VoidReasonDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetVoidReasonByNameQuery { Name = name });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<VoidReasonDto>> Add([FromQuery] CreateVoidReasonRequest req)
        {
            var result = await mediator.Send(new AddVoidReasonCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateVoidReasonRequest req)
        {
            var result = await mediator.Send(new UpdateVoidReasonCommand(id, req));
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await mediator.Send(new DeleteVoidReasonCommand(id));
            return result ? NoContent() : NotFound();
        }
    }
}