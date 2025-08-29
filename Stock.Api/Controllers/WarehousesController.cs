using MediatR;
using Microsoft.AspNetCore.Mvc;
using Stocks.Api.Commands.WarehouseCommands.Add;
using Stocks.Api.Domain;
using Stocks.Api.Helpers;
using Stocks.Api.Models;
using Stocks.Api.Queries.WarehousesQuery;

namespace Stocks.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class WarehousesController(IMediator mediator) : ControllerBase
    {

        [HttpGet("[action]")]
        public async Task<ActionResult<List<WarehouseDto>>> GetAllWarehouses()
        {
            var warehouse = await mediator.Send(new GetAllWarehousesQuery());
            return Ok(warehouse);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<WarehouseDto>> AddWarehouse([FromBody] CreateWarehouseRequest createWarehouseRequest)
        {
            return Ok(await mediator.Send(new AddWarehousecommand(createWarehouseRequest)));
        }
        //[HttpDelete("{id}")]
        //public async Task<ActionResult> DeleteProductComment(int id)
        //{
        //    try
        //    {
        //        var deleted = await _productCommentRepository.DeleteProductCommentAsync(id);
        //        if (!deleted)
        //            return NotFound($"Product comment with ID {id} not found.");

        //        return NoContent();
        //    }
        //    catch (Exception ex)
        //    {
        //        return StatusCode(500, $"Internal server error: {ex.Message}");
        //    }
        //}
    }
}