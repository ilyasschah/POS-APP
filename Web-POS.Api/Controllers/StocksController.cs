using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.StockCommands.Add;
using Products.Api.Models;
using Products.Api.Queries.StockQuery;
using Products.Api.Commands.StockCommands.Update;
using Products.Api.Commands.StockCommands.Delete;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StocksController (IMediator mediator): ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<StockDto>>> GetAllStocks([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok (await mediator.Send(new GetAllStockQuery { CompanyId = companyId }));
        }
        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<StockDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetStockByIdQuery(id, companyId)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<StockDto>> Add([FromBody] CreateStockRequest stockrequest, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var command = new AddStockCommand(stockrequest, companyId);
            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result }, result);
        }
        [HttpPut("[action]/{id:int}")]
        public async Task<ActionResult<bool>> Update([FromBody] UpdateStockRequest stockrequest, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new UpdateStockCommand(stockrequest, companyId)));
        }
        [HttpDelete("[action]/{id:int}")]
        public async Task<ActionResult> Delete(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var command = new DeleteStockCommand(id, companyId);
            var ok = await mediator.Send(command);
            return Ok(ok);
        }
    }
}
