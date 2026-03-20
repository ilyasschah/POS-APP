using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.WarehouseCommands.Add;
using Products.Api.Models;
using Products.Api.Commands.WarehouseCommands.Delete;
using Products.Api.Commands.WarehouseCommands.Update;
using Products.Api.Queries.WarehousesQuery;

namespace Products.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class WarehousesController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<WarehouseDto>>> GetAll([FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        return Ok(await mediator.Send(new GetAllWarehousesQuery { CompanyId = companyId }));
    }

    [HttpGet("[action]")]
    public async Task<ActionResult<WarehouseDto>> GetById(int id, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetWarehouseByIdQuery { Id = id, CompanyId = companyId });
        if (result == null) return NotFound($"Warehouse with ID {id} not found.");
        return Ok(result);
    }

    [HttpPost("[action]")]
    public async Task<ActionResult<WarehouseDto>> Add([FromBody] CreateWarehouseRequest request,[FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var command = new AddWarehouseCommand(request, companyId);
        var result = await mediator.Send(command);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId = companyId }, result);
    }

    [HttpPut("[action]")]
    public async Task<ActionResult<WarehouseDto>> Update([FromBody] UpdateWarehouseRequest request,[FromQuery] int companyId)
    {
        if (companyId <= 0) return BadRequest("Company ID is required");
        var command = new UpdateWarehouseCommand(request, companyId);
        var result = await mediator.Send(command);
        return Ok(result);
    }

    [HttpDelete("[action]")]
    public async Task<ActionResult<bool>> Delete([FromBody] int id, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var command = new DeleteWarehouseCommand(id, companyId);
        var result = await mediator.Send(command);
        return Ok(result);
    }
}