using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;
using Products.Api.Commands.WarehouseCommands.Add;
//using Products.Api.Commands.WarehouseCommands.Delete;
//using Products.Api.Commands.WarehouseCommands.Update;
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

    [HttpGet("[action]/{id}")]
    public async Task<ActionResult<WarehouseDto>> GetById(int id, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetWarehouseByIdQuery (id){ CompanyId = companyId });
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost("[action]")]
    public async Task<ActionResult<WarehouseDto>> Add([FromBody] CreateWarehouseRequest request, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var command = new AddWarehousecommand(request, companyId);
        var result = await mediator.Send(command);
        return CreatedAtAction(nameof(GetById), new { id = request.Name, companyId }, result);
    }

    //[HttpPut("[action]/{id:int}")]
    //public async Task<IActionResult> Update(int id, [FromBody] UpdateWarehouseRequest request, [FromQuery] int companyId)
    //{
    //    if (companyId == 0) return BadRequest("Company ID is required");
    //    var ok = await mediator.Send(new UpdateWarehouseCommand(id, request, companyId));
    //    return ok ? NoContent() : NotFound();
    //}

    //[HttpDelete("[action]/{id:int}")]
    //public async Task<IActionResult> Delete(int id, [FromQuery] int companyId)
    //{
    //    if (companyId == 0) return BadRequest("Company ID is required");
    //    var ok = await mediator.Send(new DeleteWarehouseCommand(id, companyId));
    //    return ok ? NoContent() : NotFound();
    //}
}