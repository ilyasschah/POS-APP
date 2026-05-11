using MediatR;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.UserCommands.Add;
using Api.Commands.UserCommands.Delete;
using Api.Commands.UserCommands.Update;
using Api.Queries.UserQuery;
using Api.Models;
using Api.Attributes;

namespace Api.Controllers;


[SwaggerVisible]
[Route("api/[controller]")]
[ApiController]
public class UsersController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<UserDto>>> GetAllUsers([FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        return Ok(await mediator.Send(new GetAllUsersQuery { CompanyId = companyId }));
    }

    [HttpGet("[action]")]
    public async Task<ActionResult<UserDto>> GetUserById([FromQuery] int id , [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetUserByIdQuery{Id = id, CompanyId = companyId });
        if (result == null) return NotFound($"User with ID {id} not found.");
        return Ok(result);
    }

    [HttpGet("[action]")]
    public async Task<ActionResult<UserDto>> GetByUsername([FromQuery] string username, [FromQuery] int companyId)
    {
        if (companyId == 0)
            return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetUserByUsernameQuery(username) { CompanyId = companyId });
        if (result == null) return NotFound($"User '{username}' not found.");
        return Ok(result);
    }

    [HttpPost("[action]")]
    public async Task<ActionResult<UserDto>> Add([FromBody] CreateUserRequest request, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");

        var command = new AddUserCommand(request, companyId);
        var result = await mediator.Send(command);
        return Ok(result);
    }

    [HttpPatch("[action]")]
    public async Task<ActionResult<UserDto>> UpdateUser([FromBody] UpdateUserRequest updateRequest, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var command = new UpdateUserCommand(updateRequest, companyId);
        var updatedUser = await mediator.Send(command);
        return Ok(new {Id=updateRequest.Id, Message = updatedUser ? "User updated successfully" : "User update failed"});
    }

    [HttpDelete("[action]")]
    public async Task<ActionResult<bool>> Delete([FromQuery] int id, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var command = new DeleteUserCommand(id, companyId);
        var result = await mediator.Send(command);
        return Ok(result);
    }
}