using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.StockControlCommands.Add;
using Api.Commands.StockControlCommands.Update;
using Api.Commands.StockControlCommands.Delete;
using Api.Queries.StockControlQuery;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StockControlsController(IMediator mediator) : ControllerBase
    {
    
        [HttpGet("[action]")]
        public async Task<ActionResult<StockControlDto?>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Stock Control ID is required" });

            var result = await mediator.Send(new GetStockControlByIdQuery { Id = id, CompanyId = companyId });
            return result is null ? NotFound(new { message = "Stock control not found" }) : Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<StockControlDto?>> GetByProductId([FromQuery] int productId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (productId <= 0) return BadRequest(new { message = "Product ID is required" });

            var result = await mediator.Send(new GetStockControlByProductIdQuery { ProductId = productId, CompanyId = companyId });

            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateStockControlRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            try
            {
                await mediator.Send(new AddStockControlCommand(req, companyId));
                return Ok(new { message = "Stock control added successfully" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")] // PERFECTED FOR PATCH
        public async Task<IActionResult> Update([FromBody] UpdateStockControlRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            try
            {
                var ok = await mediator.Send(new UpdateStockControlCommand(req, companyId));
                return ok
                    ? Ok(new { message = "Stock control updated successfully" })
                    : NotFound(new { message = "Stock control not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Stock Control ID is required" });
            try
            {
                var ok = await mediator.Send(new DeleteStockControlCommand(id, companyId));
                return ok
                    ? Ok(new { message = "Stock control deleted successfully" })
                    : NotFound(new { message = "Stock control not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}