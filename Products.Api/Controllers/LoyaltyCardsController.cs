// FILE: Products.Api.Controllers\LoyaltyCardsController.cs

using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.LoyaltyCardCommands.Add;
using Products.Api.Commands.LoyaltyCardCommands.Update;
using Products.Api.Commands.LoyaltyCardCommands.Delete;
using Products.Api.Queries.LoyaltyCardQuery;
using Products.Api.Models;

namespace Products.Api.Controllers;

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
