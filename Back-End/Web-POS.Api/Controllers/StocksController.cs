using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.StockCommands.Add;
using Api.Queries.StockQuery;
using Api.Commands.StockCommands.Update;
using Api.Commands.StockCommands.Delete;
using Api.Attributes;
using Api.Models;
using Microsoft.AspNetCore.Authorization;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class StocksController : ControllerBase
    {
        private readonly IMediator _mediator;

        public StocksController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<StockDto>>> GetAllStocks([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetAllStockQuery { CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<StockDto>> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetStockByIdQuery { Id = id, CompanyId = companyId }, ct));
        }

        [Authorize]
        [HttpPost("[action]")]
        public async Task<ActionResult<StockDto>> Add([FromBody] CreateStockRequest stockrequest, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new AddStockCommand(stockrequest, companyId), ct);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }

        [Authorize]
        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateStockRequest stockrequest, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            var result = await _mediator.Send(new UpdateStockCommand(stockrequest, companyId), ct);
            return Ok(new { Success = result });
        }

        [Authorize]
        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            var result = await _mediator.Send(new DeleteStockCommand(id, companyId), ct);
            return Ok(new { Message = result ? "Stock deleted successfully" : "Failed to delete stock" });
        }
    }
}