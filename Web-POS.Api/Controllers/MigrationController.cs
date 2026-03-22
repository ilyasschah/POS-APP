using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.MigrationCommands.Add;
using Api.Commands.MigrationCommands.Delete;
using Api.Commands.MigrationCommands.Update;
using Api.Queries.MigrationQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MigrationsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<MigrationDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllMigrationsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<MigrationDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetMigrationByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{version}")]
        public async Task<ActionResult<MigrationDto>> GetByVersion(string version)
        {
            var result = await mediator.Send(new GetMigrationByVersionQuery { Version = version });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<MigrationDto>> Add([FromQuery] CreateMigrationRequest req)
        {
            var result = await mediator.Send(new AddMigrationCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateMigrationRequest req)
        {
            var ok = await mediator.Send(new UpdateMigrationCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeleteMigrationCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
