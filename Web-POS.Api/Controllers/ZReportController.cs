using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ZReportCommands.Add;
using Api.Commands.ZReportCommands.Delete;
using Api.Queries.ZReportQuery;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ZReportController (IMediator mediator): ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ZReportDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllZReportsQuery()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<bool>> Add(CreateZReportRequest zReportRequest)
        {
            return Ok(await mediator.Send(new AddZReportCommand(zReportRequest)));
        }
        [HttpDelete("delete/{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteZReportCommand(id)));
        }
    }
}
