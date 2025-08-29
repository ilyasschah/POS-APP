// FILE: Sales.Api.Controllers\LoyaltyCardsController.cs

using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.LoyaltyCardCommands.Add;
using Sales.Api.Commands.LoyaltyCardCommands.Update;
using Sales.Api.Commands.LoyaltyCardCommands.Delete;
using Sales.Api.Models;
using Sales.Api.Queries.LoyaltyCardQuery;

namespace Sales.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class LoyaltyCardsController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<LoyaltyCardDto>>> GetAll()
    {
        return Ok(await mediator.Send(new GetAllLoyaltyCardsQuery()));
    }

    [HttpGet("[action]/{id}")]
    public async Task<ActionResult<LoyaltyCardDto?>> GetById(int id)
    {
        return Ok(await mediator.Send(new GetLoyaltyCardByIdQuery(id)));
    }

    [HttpPost("[action]")]
    public async Task<ActionResult> Add([FromQuery] CreateLoyaltyCardRequest createRequest)
    {
        return Ok(await mediator.Send(new AddLoyaltyCardCommand(createRequest)));
    }

    [HttpPut("[action]")]
    public async Task<IActionResult> Update([FromQuery] UpdateLoyaltyCardRequest updateRequest)
    {
        return Ok(await mediator.Send(new UpdateLoyaltyCardCommand(updateRequest)));
    }

    //DELETE: api/LoyaltyCard/delete/5
    //[HttpDelete("delete/{id}")]
    //public async Task<IActionResult> Delete(int id)
    //{
    //    var command = new DeleteLoyaltyCardCommand(id);
}
