using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.UserCommands.Add;
using Sales.Api.Commands.UserCommands.Update;
using Sales.Api.Models;
using Sales.Api.Queries.UserQuery;

namespace Sales.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class UsersController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<UserDto>>> GetAll()
    {
        return Ok(await mediator.Send(new GetAllUsersQuery()));
    }

    [HttpGet("[action]/{id}")]
    public async Task<ActionResult<UserDto?>> GetById(int id)
    {
        return Ok(await mediator.Send(new GetUserByIdQuery(id)));
    }

    [HttpGet("[action]/{username}")]
    public async Task<ActionResult<UserDto?>> GetByUsername(string username)
    {
        return Ok(await mediator.Send(new GetUserByUsernameQuery(username)));
    }

    [HttpPost("[action]")]
    public async Task<ActionResult> Add([FromQuery] CreateUserRequest createRequest)
    {
        return Ok(await mediator.Send(new AddUserCommand(createRequest)));
    }

    [HttpPut("[action]")]
    public async Task<IActionResult> Update([FromQuery] UpdateUserRequest updateRequest)
    {
        return Ok(await mediator.Send(new UpdateUserCommand(updateRequest)));
    }

    //DELETE: api/User/delete/5
    //[HttpDelete("delete/{id}")]
    //public async Task<IActionResult> Delete(int id)
    //{
    //    var command = new DeleteUserCommand(id);
}
