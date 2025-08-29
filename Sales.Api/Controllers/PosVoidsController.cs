using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.PosVoidCommands.Add;
using Sales.Api.Commands.PosVoidCommands.Delete;
using Sales.Api.Commands.PosVoidCommands.Update;
using Sales.Api.Models;
using Sales.Api.Queries.PosVoidQuery;
using static Microsoft.EntityFrameworkCore.DbLoggerCategory.Database;

namespace Sales.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PosVoidsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllPosVoidsQuery()));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PosVoidDto?>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetPosVoidByIdQuery { Id = id }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetByOrderNumber(string orderNumber)
        {
            return Ok(await mediator.Send(new GetPosVoidsByOrderNumberQuery { OrderNumber = orderNumber }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosVoidDto>> Add([FromQuery] CreatePosVoidRequest request)
        {
            return Ok(await mediator.Send(new AddPosVoidCommand(request)));
        }
        [HttpPost("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdatePosVoidRequest request)
        {
            return Ok(await mediator.Send(new UpdatePosVoidCommand (request)));
        }
        //DELETE: api/posvoids/delete/5
        [HttpDelete("Delete/{id}")]
        public async Task<IActionResult> Delete(string reason)
        {
            return Ok(await mediator.Send(new DeletePosVoidCommand(reason)));
        }
    }
}