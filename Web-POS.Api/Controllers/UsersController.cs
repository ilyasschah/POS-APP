using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;
using Products.Api.Commands.UserCommands.Add;
using Products.Api.Commands.UserCommands.Update;
using Products.Api.Queries.UserQuery;
using Products.Api.Commands.UserCommands.Delete;

namespace Products.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class UsersController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<UserDto>>> GetAll([FromQuery] int companyId)
    {
        if (companyId == 0)
            return BadRequest("Company ID is required");

        return Ok(await mediator.Send(new GetAllUsersQuery { CompanyId = companyId }));
    }

    [HttpGet("[action]/{id}")]
    public async Task<ActionResult<UserDto>> GetById(int id ,[FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetUserByIdQuery{Id = id, CompanyId = companyId });
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("[action]/{username}/{companyId}")]
    public async Task<ActionResult<UserDto>> GetByUsername(string username, [FromQuery] int companyId)
    {
        if (companyId == 0)
            return BadRequest("Company ID is required");

        return Ok(await mediator.Send(new GetUserByUsernameQuery(username) { CompanyId = companyId }));
    }

    [HttpPost("[action]/{id:int}")]
    public async Task<ActionResult<UserDto>> Add([FromBody] CreateUserRequest request, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");

        var command = new AddUserCommand(request, companyId);
        command.Request.CompanyId = companyId;

        var result = await mediator.Send(command);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
    }

    [HttpPut("[action]/{id:int}")]
    public async Task<IActionResult> Update(int id,[FromBody] UpdateUserRequest updateRequest, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");

        var ok = await mediator.Send(new UpdateUserCommand(id,updateRequest, companyId));
        return ok ? NoContent() : NotFound();
    }


    [HttpDelete("[action]/{id:int}")]
    public async Task<IActionResult> Delete(int id, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var ok = await mediator.Send(new DeleteUserCommand (id, companyId));
        return ok ? NoContent() : NotFound();
    }
}
        
