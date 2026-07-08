using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.StockCommands.Add;
using Products.Api.Queries.StockQuery;
using Products.Api.Models;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StocksController (IMediator mediator): ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<StockDto>>> GetAllStocks()
        {
            return Ok (await mediator.Send(new GetStockProductNameWarehouseNameQuery()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<StockDto>> AddStock([FromBody] CreateStockRequest stockrequest)
        {
            return Ok(await mediator.Send(new AddStockcommand(stockrequest)));
        }
    }
}
