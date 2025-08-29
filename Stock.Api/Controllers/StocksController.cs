using MediatR;
using Microsoft.AspNetCore.Mvc;
using Stocks.Api.Commands.StockCommands.Add;
using Stocks.Api.Models;
using Stocks.Api.Queries.StockQuery;

namespace Stocks.Api.Controllers
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
