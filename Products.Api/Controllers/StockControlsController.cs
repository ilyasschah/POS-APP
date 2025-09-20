using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.StockControlCommands.Add;
using Products.Api.Commands.StockControlCommands.Update;
using Products.Api.Commands.StockControlCommands.Delete;
using Products.Api.Queries.StockControlQuery;
using Products.Api.Models;

namespace Products.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class StockControlsController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<StockControlDto>>> GetAll()
    {
        return Ok(await mediator.Send(new GetAllStockControlsQuery()));
    }

    [HttpGet("[action]/{id}")]
    public async Task<ActionResult<StockControlDto?>> GetById(int id)
    {
        return Ok(await mediator.Send(new GetStockControlByIdQuery(id)));
    }

    [HttpPost("[action]")]
    public async Task<ActionResult> Add([FromQuery] CreateStockControlRequest createRequest)
    {
        return Ok(await mediator.Send(new AddStockControlCommand(createRequest)));
    }

    [HttpPut("[action]")]
    public async Task<IActionResult> Update([FromQuery] UpdateStockControlRequest updateRequest)
    {
        return Ok(await mediator.Send(new UpdateStockControlCommand(updateRequest)));
    }

    //DELETE: api/StockControl/delete/5
    //[HttpDelete("delete/{id}")]
    //public async Task<IActionResult> Delete(int id)
    //{
    //    var command = new DeleteStockControlCommand(id);
}
